Function Set-BuiltInWinSecureDNS {
    [Alias('Set-DOH')]
    [CmdletBinding()]
    [OutputType([System.String], [Microsoft.Management.Infrastructure.CimInstance])]
    param (
        [ValidateSet('Cloudflare', 'CloudFlareFamily', 'CloudFlareAntiMalware', 'Quad9' , 'Quad9MalwareBlocking', 'Google', ErrorMessage = 'The selected DNS over HTTPS provider is not supported by Windows. Please select a different provider or use the Set-CustomWinSecureDNS cmdlet.')]
        [Parameter(Mandatory = $false)][System.String]$DoHProvider = 'Cloudflare'
    )
    begin {
        # Detecting if Verbose switch is used
        [System.Boolean]$Verbose = $PSBoundParameters.Verbose.IsPresent ? $true : $false

        # Importing the $PSDefaultParameterValues to the current session, prior to everything else
        . "$WinSecureDNSMgrModuleRootPath\MainExt\PSDefaultParameterValues.ps1"

        # Importing the required sub-modules
        Import-Module -Name "$WinSecureDNSMgrModuleRootPath\Shared\Get-ActiveNetworkAdapterWinSecureDNS.psm1" -Force
        Import-Module -Name "$WinSecureDNSMgrModuleRootPath\Shared\Get-ManualNetworkAdapterWinSecureDNS.psm1" -Force
        Import-Module -Name "$WinSecureDNSMgrModuleRootPath\Shared\Select-Option.psm1" -Force

        # This service shouldn't be disabled
        # https://github.com/HotCakeX/WinSecureDNSMgr/issues/7
        if (!((Get-Service -Name 'Dnscache').StartType -ne 'Disabled')) {
            throw 'The DNS Client service status is disabled. Please start the service and try again.'
        }

        # Get the DoH domain from the hashtable - Since all of the DoH domains are identical for the same provider, only getting the first item in the array
        [System.String]$DetectedDoHTemplate = ($BuiltInDoHTemplatesReference.GetEnumerator() | Where-Object { $_.Key -eq $DoHProvider }).Value.Values.Values[0]

        # Automatically detect the correct network adapter
        [Microsoft.Management.Infrastructure.CimInstance]$ActiveNetworkInterface = Get-ActiveNetworkAdapterWinSecureDNS

        # Display the detected network adapter and ask the user if it's correct
        $ActiveNetworkInterface

        # Loop until the user confirms the detected adapter is the correct one, Selects the correct network adapter or Cancels
        switch (Select-Option -Options 'Yes', 'No - Select Manually', 'Cancel' -Message "`nIs the detected network adapter correct ?") {
            'Yes' {
                $ActiveNetworkInterface = $ActiveNetworkInterface
            }
            'No - Select Manually' {
                [Microsoft.Management.Infrastructure.CimInstance]$ActiveNetworkInterface = Get-ManualNetworkAdapterWinSecureDNS
            }
            'Cancel' {
                Write-Host -Object 'Exiting...' -ForegroundColor Yellow
                # Set the $shouldExit variable to $True indicating the subsequent blocks to exit the function
                [System.Boolean]$ShouldExit = $True
                return
            }
        }

        # Set the $shouldExit variable to $True and exit the function in the subsequent blocks if no network adapter is selected
        if (!$ActiveNetworkInterface) {
            $ShouldExit = $True
            return
        }
    }

    process {
        # if the user selected Cancel, do not proceed with the process block
        if ($ShouldExit) { Return }

        # reset the network adapter's DNS servers back to default to take care of any IPv6 strays
        Set-DnsClientServerAddress -InterfaceIndex $ActiveNetworkInterface.ifIndex -ResetServerAddresses

        # delete all other previous DoH settings for ALL Interface - Windows behavior in settings when changing DoH settings is to delete all DoH settings for the interface we are modifying
        # but we need to delete all DoH settings for ALL interfaces in here because every time we virtualize a network adapter with external switch of Hyper-V,
        # Hyper-V assigns a new GUID to it, so it's better not to leave any leftover in the registry and clean up after ourselves
        $null = Remove-Item -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\*' -Recurse

        # Define empty arrays to store IPv4 and IPv6 addresses
        [System.String[]]$DoHIPs = @()
        [System.String[]]$IPV4s = @()
        [System.String[]]$IPV6s = @()
        [System.Boolean]$IsExtraProvider = $false

        # If using a provider that is not available by default in Windows then get its IP addresses from the JSON file
        if ($DoHProvider -in 'CloudFlareFamily', 'CloudFlareAntiMalware', 'Quad9MalwareBlocking') {

            $IsExtraProvider = $true

            [System.String[]]$DoHIPs = foreach ($Item in $BuiltInDoHTemplatesReference.GetEnumerator()) {
                if ($Item.Key -eq $DoHProvider) {
                    $Item.Value.Values.Keys
                }
            }

            # Detect version of each IP address and store them in the appropriate array
            foreach ($IP in $DoHIPs) {
                if (([System.Net.IPAddress]$IP).AddressFamily -eq 'InterNetwork') {
                    $IPV4s += $IP
                }
                elseif (([System.Net.IPAddress]$IP).AddressFamily -eq 'InterNetworkV6') {
                    $IPV6s += $IP
                }
            }

            # check if there is any IP address already associated with $DetectedDoHTemplate and if so, delete them
            foreach ($Item in Get-DnsClientDohServerAddress) {
                if ($Item.dohTemplate -eq $DetectedDoHTemplate) {
                    foreach ($OldIP in $Item.ServerAddress) {
                        Remove-DnsClientDohServerAddress -ServerAddress $OldIP
                    }
                }
            }

            Write-Verbose -Message 'Checking if the IP addresses of the currently selected DoH domain already exist and then deleting them'
            foreach ($Item in Get-DnsClientDohServerAddress) {
                if ($Item.ServerAddress -in $DoHIPs) {
                    Remove-DnsClientDohServerAddress -ServerAddress $Item.ServerAddress
                }
            }

        }
        else {
            # Get the IP addresses associated with the built-in DOH servers
            [System.String[]]$DoHIPs = foreach ($Item in Get-DnsClientDohServerAddress) {
                if ($Item.DohTemplate -eq $DetectedDoHTemplate) {
                    $Item.ServerAddress
                }
            }

            # Detect version of each IP address and store them in the appropriate array
            foreach ($IP in $DoHIPs) {
                if (([System.Net.IPAddress]$IP).AddressFamily -eq 'InterNetwork') {
                    $IPV4s += $IP
                }
                elseif (([System.Net.IPAddress]$IP).AddressFamily -eq 'InterNetworkV6') {
                    $IPV6s += $IP
                }
            }
        }

        foreach ($IPV4 in $IPV4s) {
            # defining registry path for DoH settings of the $ActiveNetworkInterface based on its GUID for IPv4
            [System.String]$PathV4 = "Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\$($ActiveNetworkInterface.InterfaceGuid)\DohInterfaceSettings\Doh\$IPV4"

            # add DoH settings for the specified Network adapter based on its GUID in registry
            # value 1 for DohFlags key means use automatic template for DoH, 2 means manual template, since we add our template to Windows, it's predefined so we use value 1
            $null = New-Item -Path $PathV4 -Force
            $null = New-ItemProperty -Path $PathV4 -Name 'DohFlags' -Value 1 -PropertyType 'Qword' -Force

            if (!$IsExtraProvider) {
                Set-DnsClientDohServerAddress -ServerAddress $IPV4 -DohTemplate $DetectedDoHTemplate -AllowFallbackToUdp $False -AutoUpgrade $True
            }
            else {
                Write-Verbose -Message 'Associating the new IPv4s with the selected DoH template in Windows DoH template predefined list'
                $null = Add-DnsClientDohServerAddress -ServerAddress $IPV4 -DohTemplate $DetectedDoHTemplate -AllowFallbackToUdp $False -AutoUpgrade $True
            }
        }

        foreach ($IPV6 in $IPV6s) {

            # defining registry path for DoH settings of the $ActiveNetworkInterface based on its GUID for IPv6
            [System.String]$PathV6 = "Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\$($ActiveNetworkInterface.InterfaceGuid)\DohInterfaceSettings\Doh6\$IPV6"

            # add DoH settings for the specified Network adapter based on its GUID in registry
            # value 1 for DohFlags key means use automatic template for DoH, 2 means manual template, since we already added our template to Windows, it's considered predefined, so we use value 1
            $null = New-Item -Path $PathV6 -Force
            $null = New-ItemProperty -Path $PathV6 -Name 'DohFlags' -Value 1 -PropertyType 'Qword' -Force

            if (!$IsExtraProvider) {
                Set-DnsClientDohServerAddress -ServerAddress $IPV6 -DohTemplate $DetectedDoHTemplate -AllowFallbackToUdp $False -AutoUpgrade $True
            }
            else {
                Write-Verbose -Message 'Associating the new IPv4s with the selected DoH template in Windows DoH template predefined list'
                $null = Add-DnsClientDohServerAddress -ServerAddress $IPV6 -DohTemplate $DetectedDoHTemplate -AllowFallbackToUdp $False -AutoUpgrade $True
            }
        }

        # this is responsible for making the changes in Windows settings UI > Network and internet > $ActiveNetworkInterface.Name
        Set-DnsClientServerAddress -ServerAddresses $DoHIPs -InterfaceIndex $ActiveNetworkInterface.ifIndex
    }

    End {
        # if the user selected Cancel, do not proceed with the end block
        if ($ShouldExit) { Return }

        Write-Verbose -Message 'Clearing the DNS client cache'
        Clear-DnsClientCache

        Write-Host -Object "DNS over HTTPS (DoH) is now configured for $($ActiveNetworkInterface.Name) using $DoHProvider provider." -ForegroundColor Green

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
    Easily and quickly configure DNS over HTTPS (DoH) in Windows
.LINK
    https://github.com/HotCakeX/WinSecureDNSMgr
.DESCRIPTION
    Easily and quickly configure DNS over HTTPS (DoH) in Windows
.PARAMETER DoHProvider
    The name of the 3 built-in DNS over HTTPS providers: Cloudflare, Google and Quad9
    If no value is provided, the default provider is Cloudflare
.EXAMPLE
    Set-BuiltInWinSecureDNS -DoHProvider Cloudflare
    Set-DOH -DoHProvider Cloudflare
.PARAMETER Verbose
    Switch to enable verbose output
.INPUTS
    System.String
.OUTPUTS
    System.String
    Microsoft.Management.Infrastructure.CimInstance
#>
}
