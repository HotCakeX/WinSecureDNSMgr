function Set-CustomWinSecureDNS {
    [Alias('Set-CDOH')]
    [CmdletBinding()]
    param (
        # checking to make sure the DoH template is valid and not one of the built-in ones
        [ValidatePattern('^https\:\/\/.+\..+\/.*', ErrorMessage = 'The value provided for the parameter DoHTemplate is not a valid DNS over HTTPS template. Please enter a valid DNS over HTTPS template that starts with https, has a TLD and a slash after it. E.g.: https://template.com/')]
        [ValidateScript({ $_ -notmatch 'https://(cloudflare-dns|dns\.google|dns\.quad9)\.com/dns-query' }, ErrorMessage = 'The DoH template you selected is one of the Windows built-in ones. Please select a different DoH template or use the Set-BuiltInWinSecureDNS cmdlet.')]
        [Parameter(Mandatory)][System.String]$DoHTemplate,

        [ValidateCount(1, 2)][System.Net.IPAddress[]]$IPV4s,
        [ValidateCount(1, 2)][System.Net.IPAddress[]]$IPV6s
    )
    begin {

        [System.Boolean]$AutoDetectDoHIPs = $false

        # If IP addresses were provided manually by user, verify their version
        if ($IPV4s) {
            $IPV4s | ForEach-Object -Process { if ($_.AddressFamily -ne 'InterNetwork') { throw "The IP address $_ is not a valid IPv4 address." } }
        }
        if ($IPV6s) {
            $IPV6s | ForEach-Object -Process { if ($_.AddressFamily -ne 'InterNetworkV6') { throw "The IP address $_ is not a valid IPv6 address." } }
        }

        # if no IP addresses were provided manually by user, set the $AutoDetectDoHIPs variable to $True
        if (!$IPV4s -and !$IPV6s) {
            $AutoDetectDoHIPs = $True
        }

        # Detect the active network adapter automatically
        [Microsoft.Management.Infrastructure.CimInstance]$ActiveNetworkInterface = Get-ActiveNetworkAdapterWinSecureDNS

        # Display the detected network adapter and ask the user if it's correct
        $ActiveNetworkInterface

        switch (Select-Option -Options 'Yes', 'No - Select Manually', 'Cancel' -Message "`nIs the detected network adapter correct ?") {
            'Yes' {
                $ActiveNetworkInterface = $ActiveNetworkInterface
            }
            'No - Select Manually' {
                # Detect the active network adapter manually
                $ActiveNetworkInterface = Get-ManualNetworkAdapterWinSecureDNS
            }
            'Cancel' {
                [System.Boolean]$ShouldExit = $True
                return
            }
        }

        # if user chose to cancel the Get-ManualNetworkAdapterWinSecureDNS function, set the $shouldExit variable to $True and exit the function in the Process block
        if (!$ActiveNetworkInterface) { $ShouldExit = $True; return }

        # Detect the IP address(s) of the DoH domain automatically if not provided by the user
        if ($AutoDetectDoHIPs) {

            # Define the regex for extracting the domain name
            $DomainExtractionRegex = '(?<=https\:\/\/).+?(?=\/)'

            # Test if the input matches the regex
            $DoHTemplate -match $DomainExtractionRegex
            # Access the matched value
            $Domain = $Matches[0]

            Write-Verbose -Message "The extracted domain name is $Domain"

            # Get the IP addresses of the DoH domain
            $IPV4s = Get-IPv4DoHServerIPAddressWinSecureDNSMgr -Domain $Domain
            $IPV6s = Get-IPv6DoHServerIPAddressWinSecureDNSMgr -Domain $Domain

            # If no IP addresses were found for either versions, exit the function
            if (($null -eq $IPV4s) -and ($null -eq $IPV6s)) {
                Throw "No IP addresses were found for the domain $Domain. Please make sure the domain is valid and try again, alternatively you can use the Set-BuiltInWinSecureDNS cmdlet to set one of the built-in DoH templates."
                [System.Boolean]$ShouldExit = $True
                return
            }
        }
    }
    process {

        # if the user selected Cancel, do not proceed with the process block
        if ($ShouldExit) { break }

        # check if there is any IP address already associated with "$DoHTemplate" template
        $OldIPs = (Get-DnsClientDohServerAddress | Where-Object { $_.dohTemplate -eq $DoHTemplate }).serveraddress

        # if there is, remove them
        if ($OldIPs) {
            $OldIPs | ForEach-Object -Process {
                Remove-DnsClientDohServerAddress -ServerAddress $_
            }
        }

        # check if the IP addresses of the currently selected domain already exist and then delete them
        Get-DnsClientDohServerAddress | ForEach-Object -Process {
            if ($_.ServerAddress -in $IPV4s -or $_.ServerAddress -in $IPV6s) {
                Remove-DnsClientDohServerAddress -ServerAddress $_.ServerAddress
            }
        }

        # reset the network adapter's DNS servers back to default to take care of any IPv6 strays
        Set-DnsClientServerAddress -InterfaceIndex $ActiveNetworkInterface.ifIndex -ResetServerAddresses

        # delete all other previous DoH settings for ALL Interface - Windows behavior in settings when changing DoH settings is to delete all DoH settings for the interface we are modifying
        # but we need to delete all DoH settings for ALL interfaces in here because every time we virtualize a network adapter with external switch of Hyper-V,
        # Hyper-V assigns a new GUID to it, so it's better not to leave any leftover in the registry and clean up after ourselves
        Remove-Item -Path 'HKLM:System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\*' -Recurse

        if ($null -ne $IPV4s) {

            # loop through each IPv4
            $IPV4s | ForEach-Object -Process {

                # defining registry path for DoH settings of the $ActiveNetworkInterface based on its GUID for IPv4
                [System.String]$PathV4 = "HKLM:System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\$($ActiveNetworkInterface.InterfaceGuid)\DohInterfaceSettings\Doh\$_"

                # associating the new IPv4s with our DoH template in Windows DoH template predefined list
                Add-DnsClientDohServerAddress -ServerAddress $_ -DohTemplate $DoHTemplate -AllowFallbackToUdp $False -AutoUpgrade $True

                # add DoH settings for the specified Network adapter based on its GUID in registry
                # value 1 for DohFlags key means use automatic template for DoH, 2 means manual template, since we add our template to Windows, it's predefined so we use value 1
                New-Item -Path $PathV4 -Force | Out-Null
                New-ItemProperty -Path $PathV4 -Name 'DohFlags' -Value '1' -PropertyType 'Qword' -Force
            }
        }

        # Making sure the DoH server supports and has IPv6 addresses
        if ($null -ne $IPV6s) {

            # loop through each IPv6
            $IPV6s | ForEach-Object -Process {

                # defining registry path for DoH settings of the $ActiveNetworkInterface based on its GUID for IPv6
                [System.String]$PathV6 = "HKLM:System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\$($ActiveNetworkInterface.InterfaceGuid)\DohInterfaceSettings\Doh6\$_"

                # associating the new IPv6s with our DoH template in Windows DoH template predefined list
                Add-DnsClientDohServerAddress -ServerAddress $_ -DohTemplate $DoHTemplate -AllowFallbackToUdp $False -AutoUpgrade $True

                # add DoH settings for the specified Network adapter based on its GUID in registry
                # value 1 for DohFlags key means use automatic template for DoH, 2 means manual template, since we already added our template to Windows, it's considered predefined, so we use value 1
                New-Item -Path $PathV6 -Force | Out-Null
                New-ItemProperty -Path $PathV6 -Name 'DohFlags' -Value '1' -PropertyType 'Qword' -Force
            }
        }

        # gather IPv4s and IPv6s all in one place
        [System.String[]]$NewIPs = $IPV4s + $IPV6s

        # this is responsible for making the changes in Windows settings UI > Network and internet > $ActiveNetworkInterface.Name
        Set-DnsClientServerAddress -ServerAddresses $NewIPs -InterfaceIndex $ActiveNetworkInterface.ifIndex

    }

    end {
        if ($ShouldExit) { break }

        # clear DNS client Cache
        Clear-DnsClientCache

        Write-Host -Object "DNS over HTTPS has been successfully configured for $($ActiveNetworkInterface.Name) using $DoHTemplate template." -ForegroundColor Green

        # Define the name and path of the task
        [System.String]$TaskName = 'Dynamic DoH Server IP check'
        [System.String]$TaskPath = '\DDoH\'

        # Try to get the Dynamic DoH task and delete it if it exists
        if (Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Confirm:$false
        }
    }
    <#
.SYNOPSIS
This function is a wrapper around the official Microsoft methods to configure DNS over HTTPS in Windows

.LINK
https://github.com/HotCakeX/WinSecureDNSMgr

.DESCRIPTION
This script is a wrapper around the official Microsoft methods to configure DNS over HTTPS in Windows.
If no IP address is provided for the DoH template, they will be detected automatically.

.FUNCTIONALITY
Using official Microsoft methods configures DNS over HTTPS in Windows

.PARAMETER DoHProvider
The name of the 3 built-in DNS over HTTPS providers: Cloudflare, Google and Quad9

.PARAMETER DoHTemplate
Enter a custom DoH template URL that starts with https, has a TLD and a slash after it. E.g.: https://template.com/"

.PARAMETER IPV4s
Enter 1 or 2 IPv4 and/or IPv6 addresses separated by comma

.PARAMETER IPV6s
Enter 1 or 2 IPv4 and/or IPv6 addresses separated by comma

.EXAMPLE
Set-CustomWinSecureDNS -DoHTemplate https://example.com/
Set-CDOH -DoHTemplate https://example.com -IPV4s 1.2.3.4 -IPV6s 2001:db8::8a2e:370:7334

#>
}
