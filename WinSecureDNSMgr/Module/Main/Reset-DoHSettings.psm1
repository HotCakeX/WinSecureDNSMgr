Function Reset-DoHSettings {
    [Alias('Reset-DoH')]
    [CmdletBinding()]
    [OutputType([System.Void])]
    param()

    # Importing the $PSDefaultParameterValues to the current session, prior to everything else
    . "$WinSecureDNSMgrModuleRootPath\MainExt\PSDefaultParameterValues.ps1"

    # This service shouldn't be disabled
    # https://github.com/HotCakeX/WinSecureDNSMgr/issues/7
    if (!((Get-Service -Name 'Dnscache').StartType -ne 'Disabled')) {
        throw 'The DNS Client service status is disabled. Please start the service and try again.'
    }

    Write-Verbose -Message 'Displaying non-system DoH templates.'
    foreach ($DNSAddr in Get-DnsClientDohServerAddress) {
        if ($DNSAddr.DohTemplate -notin $BuiltInDoHTemplatesReference.Values.Values.Values) {
            Write-Verbose -Message "Non-System DoH template with the Server Address $($_.ServerAddress) and Domain $($_.DohTemplate) detected."
        }
    }

    Write-Verbose -Message 'Resetting the DNS server IP addresses of all network adapters to the default values'
    $(Get-DnsClientServerAddress).InterfaceIndex | Select-Object -Unique | ForEach-Object -Process {
        Set-DnsClientServerAddress -ResetServerAddresses -InterfaceIndex $_
    }

    Write-Verbose -Message 'Removing all DoH templates from the system.'
    foreach ($Item in Get-DnsClientDohServerAddress) {
        Remove-DnsClientDohServerAddress -InputObject $Item
    }

    Write-Verbose -Message 'Restoring the default Windows DoH templates.'
    foreach ($DoH in $BuiltInDoHTemplatesReference.GetEnumerator()) {

        # Loop over IPv4 details
        foreach ($IPv4s in $DoH.Value.GetEnumerator() | Where-Object -FilterScript { $_.name -eq 'IPv4' }) {

            # Loop over each IPv4 address and its DoH domain
            foreach ($IPv4 in $IPv4s.Value.GetEnumerator()) {
                $null = Add-DnsClientDohServerAddress -AllowFallbackToUdp $false -AutoUpgrade $True -ServerAddress $IPv4.Name -DohTemplate $IPv4.Value
            }
        }

        # Loop over IPv6 details
        foreach ($IPv6s in $DoH.Value.GetEnumerator() | Where-Object -FilterScript { $_.name -eq 'IPv6' }) {

            # Loop over each IPv6 address and its DoH domain
            foreach ($IPv6 in $IPv6s.Value.GetEnumerator()) {
                $null = Add-DnsClientDohServerAddress -AllowFallbackToUdp $false -AutoUpgrade $True -ServerAddress $IPv6.Name -DohTemplate $IPv6.Value
            }
        }
    }

    <#
.SYNOPSIS
    Removes all of the saved DoH templates from the system and then restores back the default templates
    Resets the DNS server IP addresses of all network adapters to the default values
.INPUTS
    None
.OUTPUTS
    System.Void
.PARAMETER Verbose
    Switch to enable verbose output
#>
}
