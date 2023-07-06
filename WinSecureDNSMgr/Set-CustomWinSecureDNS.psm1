function Set-CustomWinSecureDNS {
    [Alias("Set-CDOH")]
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        # checking to make sure the DoH template is valid and not one of the built-in ones
        [ValidatePattern("^https\:\/\/.+\..+\/.*", ErrorMessage = "The value provided for the parameter DoHTemplate is not a valid DNS over HTTPS template. Please enter a valid DNS over HTTPS template that starts with https, has a TLD and a slash after it. E.g.: https://template.com/")]
        [ValidateScript({ $_ -notmatch "https://(cloudflare-dns|dns\.google|dns\.quad9)\.com/dns-query" }, ErrorMessage = "The DoH template you selected is one of the Windows built-in ones. Please select a different DoH template or use the Set-BuiltInWinSecureDNS cmdlet.")]
        [Parameter(Mandatory)][string]$DoHTemplate,
        
        # The parameter can either accept 1 or 2 IPv4 addresses
        [ValidateCount(1, 2)][ipaddress[]]$IPV4s,
        
        # The parameter can either accept 1 or 2 IPv6 addresses
        [ValidateCount(1, 2)][ipaddress[]]$IPV6s
    )
    begin {
        
        $AutoDetectDoHIPs = $false

        # If IP addresses were provided manually by user, verify their version
        if ($IPV4s) {
            $IPV4s | ForEach-Object { if ($_.AddressFamily -ne "InterNetwork") { throw "The IP address $_ is not a valid IPv4 address." } }
        }
        if ($IPV6s) {
            $IPV6s | ForEach-Object { if ($_.AddressFamily -ne "InterNetworkV6") { throw "The IP address $_ is not a valid IPv6 address." } }
        }  

        # if no IP addresses were provided manually by user, set the $AutoDetectDoHIPs variable to $true
        if (!$IPV4s -and !$IPV6s) {
            $AutoDetectDoHIPs = $true
        }

        # Detect the active network adapter automatically
        $ActiveNetworkInterface = Get-ActiveNetworkAdapterWinSecureDNS 
        $ActiveNetworkInterface

        switch (Select-Option -Options "Yes", "No - Select Manually", "Cancel" -Message "`nIs the detected network adapter correct ?") {
            "Yes" {
                $ActiveNetworkInterface = $ActiveNetworkInterface
            }
            "No - Select Manually" {
                # Detect the active network adapter manually
                $ActiveNetworkInterface = Get-ManualNetworkAdapterWinSecureDNS          
            } # properly exiting this advanced function is a bit tricky, so we use a variable to control the loop
            "Cancel" { $ShouldExit = $true; return } 
        }
        
        # if user chose to cancel the Get-ManualNetworkAdapterWinSecureDNS function, set the $shouldExit variable to $true and exit the function in the Process block
        if (!$ActiveNetworkInterface) { $ShouldExit = $true; return }

        # Detect the IP address(s) of the DoH domain automatically if not provided by the user
        if ($AutoDetectDoHIPs) {

            # Define the regex for extracting the domain name
            $DomainExtractionRegex = '(?<=https\:\/\/).+?(?=\/)'

            # Test if the input matches the regex
            $DoHTemplate -match $DomainExtractionRegex
            # Access the matched value
            $domain = $Matches[0]
    
            Write-Debug -Message "The extracted domain name is $domain`n"                                
            # Get the IP addresses of the DoH domain
            $IPV4s = Get-IPv4DoHServerIPAddressWinSecureDNSMgr -Domain $domain
            $IPV6s = Get-IPv6DoHServerIPAddressWinSecureDNSMgr -Domain $domain

            # If no IP addresses were found for either versions, exit the function
            if ($null -eq $IPV4s -and $null -eq $IPV6s) {
                Write-Error -Message "`nNo IP addresses were found for the domain $domain. Please make sure the domain is valid and try again, alternatively you can use the Set-BuiltInWinSecureDNS cmdlet to set one of the built-in DoH templates."
                $ShouldExit = $true; return 
            }
        } 
    }
    process {

        # if the user selected Cancel, do not proceed with the process block
        if ($ShouldExit) { break }

        # check if there is any IP address already associated with "$DoHTemplate" template
        $oldIPs = (Get-DnsClientDohServerAddress | Where-Object { $_.dohTemplate -eq $DoHTemplate }).serveraddress
        # if there is, remove them
        if ($oldIPs) {
            $oldIPs | ForEach-Object {
                remove-DnsClientDohServerAddress -ServerAddress $_
            }
        }

        # check if the IP addresses of the currently selected domain already exist and then delete them
        Get-DnsClientDohServerAddress | ForEach-Object {
            if ($_.ServerAddress -in $IPV4s -or $_.ServerAddress -in $IPV6s) {
                remove-DnsClientDohServerAddress -ServerAddress $_.ServerAddress
                $_
            }
        }                       

        # reset the network adapter's DNS servers back to default to take care of any IPv6 strays
        Set-DnsClientServerAddress -InterfaceIndex $ActiveNetworkInterface.ifIndex -ResetServerAddresses -ErrorAction Stop

        # delete all other previous DoH settings for ALL Interface - Windows behavior in settings when changing DoH settings is to delete all DoH settings for the interface we are modifying 
        # but we need to delete all DoH settings for ALL interfaces in here because every time we virtualize a network adapter with external switch of Hyper-V,
        # Hyper-V assigns a new GUID to it, so it's better not to leave any leftover in the registry and clean up after ourselves
        Remove-item "HKLM:System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\*" -Recurse    

        if ($null -ne $IPV4s) {
            # loop through each IPv4
            $IPV4s | foreach-Object {
                # defining registry path for DoH settings of the $ActiveNetworkInterface based on its GUID for IPv4
                $Path = "HKLM:System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\$($ActiveNetworkInterface.InterfaceGuid)\DohInterfaceSettings\Doh\$_"
                # associating the new IPv4s with our DoH template in Windows DoH template predefined list
                Add-DnsClientDohServerAddress -ServerAddress $_ -DohTemplate $DoHTemplate -AllowFallbackToUdp $False -AutoUpgrade $True
                # add DoH settings for the specified Network adapter based on its GUID in registry
                # value 1 for DohFlags key means use automatic template for DoH, 2 means manual template, since we add our template to Windows, it's predefined so we use value 1
                New-Item -Path $Path -Force | Out-Null  
                New-ItemProperty -Path $Path -Name "DohFlags" -Value 1 -PropertyType Qword -Force
            }
        }
   
        # Making sure the DoH server supports and has IPv6 addresses
        if ($null -ne $IPV6s) {
            # loop through each IPv6
            $IPV6s | foreach-Object {
                # defining registry path for DoH settings of the $ActiveNetworkInterface based on its GUID for IPv6
                $Path = "HKLM:System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\$($ActiveNetworkInterface.InterfaceGuid)\DohInterfaceSettings\Doh6\$_"
                # associating the new IPv6s with our DoH template in Windows DoH template predefined list
                Add-DnsClientDohServerAddress -ServerAddress $_ -DohTemplate $DoHTemplate -AllowFallbackToUdp $False -AutoUpgrade $True
                # add DoH settings for the specified Network adapter based on its GUID in registry
                # value 1 for DohFlags key means use automatic template for DoH, 2 means manual template, since we already added our template to Windows, it's considered predefined, so we use value 1
                New-Item -Path $Path -Force | Out-Null  
                New-ItemProperty -Path $Path -Name "DohFlags" -Value 1 -PropertyType Qword -Force
            }
        }
        # gather IPv4s and IPv6s all in one place
        $NewIPs = $IPV4s + $IPV6s
       
        # this is responsible for making the changes in Windows settings UI > Network and internet > $ActiveNetworkInterface.Name
        Set-DnsClientServerAddress -ServerAddresses $NewIPs -InterfaceIndex $ActiveNetworkInterface.ifIndex -ErrorAction Stop
        
    }

    end {
        # clear DNS client Cache
        Clear-DnsClientCache

        Write-Host "`nDNS over HTTPS has been successfully configured for $($ActiveNetworkInterface.Name) using $DoHTemplate template.`n" -ForegroundColor Green
    }
    <#
.SYNOPSIS
This script is a wrapper around the official Microsoft methods to configure DNS over HTTPS in Windows

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
