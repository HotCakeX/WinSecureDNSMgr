Function Set-BuiltInWinSecureDNS {
    [Alias('Set-DOH')]
    [CmdletBinding()]
    param (
        [ValidateScript({ $_ -in $BuiltInDoHTemplatesReference.Keys }, ErrorMessage = 'The selected DNS over HTTPS provider is not supported by Windows. Please select a different provider or use the Set-CustomWinSecureDNS cmdlet.')]
        [Parameter(Mandatory = $true)][System.String]$DoHProvider
    )
    begin {

        # Get the DoH domain of the Cloudflare from the hashtable - Since all of the DoH domains are identical for the same provider, only getting the first item in the array
        [System.String]$DetectedDoHTemplate = ($BuiltInDoHTemplatesReference.GetEnumerator() | Where-Object { $_.Key -eq $DoHProvider }).Value.Values.Values[0]

        # Automatically detect the correct network adapter
        $ActiveNetworkInterface = Get-ActiveNetworkAdapterWinSecureDNS
        $ActiveNetworkInterface

        # loop until the user confirms the detected adapter is the correct one, Selects the correct network adapter or Cancels
        switch (Select-Option -Options 'Yes', 'No - Select Manually', 'Cancel' -Message "`nIs the detected network adapter correct ?") {
            'Yes' {
                $ActiveNetworkInterface = $ActiveNetworkInterface
            }
            'No - Select Manually' {
                $ActiveNetworkInterface = Get-ManualNetworkAdapterWinSecureDNS
            } # properly exiting this advanced function is a bit tricky, so we use a variable to control the loop
            'Cancel' { $ShouldExit = $true; return }
        }

        # if user chose to cancel the Get-ManualNetworkAdapterWinSecureDNS function, set the $shouldExit variable to $true and exit the function in the Process block
        if (!$ActiveNetworkInterface) { $ShouldExit = $true; return }
    }

    process {
        # if the user selected Cancel, do not proceed with the process block
        if ($ShouldExit) { break }

        # reset the network adapter's DNS servers back to default to take care of any IPv6 strays
        Set-DnsClientServerAddress -InterfaceIndex $ActiveNetworkInterface.ifIndex -ResetServerAddresses -ErrorAction Stop

        # delete all other previous DoH settings for ALL Interface - Windows behavior in settings when changing DoH settings is to delete all DoH settings for the interface we are modifying
        # but we need to delete all DoH settings for ALL interfaces in here because every time we virtualize a network adapter with external switch of Hyper-V,
        # Hyper-V assigns a new GUID to it, so it's better not to leave any leftover in the registry and clean up after ourselves
        Remove-Item -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\*' -Recurse | Out-Null

        $DoHIPs = (Get-DnsClientDohServerAddress | Where-Object { $_.DohTemplate -eq $DetectedDoHTemplate }).ServerAddress

        $DoHIPs | ForEach-Object {

            # use the ipaddress type accelerator to check if the address is IPv4 or IPv6
            $IP = [ipaddress]$_
            if ($IP.AddressFamily -eq 'InterNetwork') {
                # defining registry path for DoH settings of the $ActiveNetworkInterface based on its GUID for IPv4
                $Path = "Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\$($ActiveNetworkInterface.InterfaceGuid)\DohInterfaceSettings\Doh\$_"

                # add DoH settings for the specified Network adapter based on its GUID in registry
                # value 1 for DohFlags key means use automatic template for DoH, 2 means manual template, since we add our template to Windows, it's predefined so we use value 1
                New-Item -Path $Path -Force | Out-Null
                New-ItemProperty -Path $Path -Name 'DohFlags' -Value 1 -PropertyType Qword -Force

                Set-DnsClientDohServerAddress -ServerAddress $_ -DohTemplate $DetectedDoHTemplate -AllowFallbackToUdp $False -AutoUpgrade $True
            }
            elseif ($IP.AddressFamily -eq 'InterNetworkV6') {
                # defining registry path for DoH settings of the $ActiveNetworkInterface based on its GUID for IPv6
                $Path = "Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\$($ActiveNetworkInterface.InterfaceGuid)\DohInterfaceSettings\Doh6\$_"

                # add DoH settings for the specified Network adapter based on its GUID in registry
                # value 1 for DohFlags key means use automatic template for DoH, 2 means manual template, since we already added our template to Windows, it's considered predefined, so we use value 1
                New-Item -Path $Path -Force | Out-Null
                New-ItemProperty -Path $Path -Name 'DohFlags' -Value 1 -PropertyType Qword -Force

                Set-DnsClientDohServerAddress -ServerAddress $_ -DohTemplate $DetectedDoHTemplate -AllowFallbackToUdp $False -AutoUpgrade $True
            }
        }

        # this is responsible for making the changes in Windows settings UI > Network and internet > $ActiveNetworkInterface.Name
        Set-DnsClientServerAddress -ServerAddresses $DoHIPs -InterfaceIndex $ActiveNetworkInterface.ifIndex -ErrorAction Stop
    }

    end {
        # if the user selected Cancel, do not proceed with the process block
        if ($ShouldExit) { break }

        # clear DNS client Cache
        Clear-DnsClientCache

        Write-Host "`nDNS over HTTPS (DoH) is now configured for $($ActiveNetworkInterface.Name) using $DoHProvider provider.`n" -ForegroundColor Green

        # Define the name and path of the task
        $taskName = 'Dynamic DoH Server IP check'
        $taskPath = '\DDoH\'

        # Try to get the Dynamic DoH task and delete it if it exists
        if (Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false
        }
    }

    <#
.SYNOPSIS
Easily and quickly configure DNS over HTTPS (DoH) in Windows

.LINK
https://github.com/HotCakeX/WinSecureDNSMgr

.DESCRIPTION
Easily and quickly configure DNS over HTTPS (DoH) in Windows

.PARAMETER DoHProvider
The name of the 3 built-in DNS over HTTPS providers: Cloudflare, Google and Quad9

.EXAMPLE
Set-BuiltInWinSecureDNS -DoHProvider Cloudflare
Set-DOH -DoHProvider Cloudflare

#>
}
