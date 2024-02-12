Function Reset-DoHSettings {
    [Alias('Reset-DoH')]
    [CmdletBinding()]
    [OutputType([System.Void])]
    param()

    # Importing the $PSDefaultParameterValues to the current session, prior to everything else
    . "$WinSecureDNSMgrModuleRootPath\MainExt\PSDefaultParameterValues.ps1"

    Write-Verbose -Message 'Displaying non-system DoH templates.'
    Get-DnsClientDohServerAddress | Where-Object -FilterScript { $_.DohTemplate -notin $BuiltInDoHTemplatesReference.Values.Values.Values } |
    ForEach-Object -Process {
        Write-Verbose -Message "Non-System DoH template with the Server Address $($_.ServerAddress) and Domain $($_.DohTemplate) detected."
    }

    Write-Verbose -Message 'Resetting the DNS server IP addresses of all network adapters to the default values'
    $(Get-DnsClientServerAddress).InterfaceIndex | Select-Object -Unique | ForEach-Object -Process {
        Set-DnsClientServerAddress -ResetServerAddresses -InterfaceIndex $_
    }

    Write-Verbose -Message 'Removing all DoH templates from the system.'
    Get-DnsClientDohServerAddress | ForEach-Object -Process {
        Remove-DnsClientDohServerAddress -InputObject $_
    }

    Write-Verbose -Message 'Restoring the default Windows DoH templates.'
    foreach ($DoH in $BuiltInDoHTemplatesReference.GetEnumerator()) {

        # Loop over IPv4 details
        foreach ($IPv4s in $DoH.Value.GetEnumerator() | Where-Object -FilterScript { $_.name -eq 'IPv4' }) {

            # Loop over each IPv4 address and its DoH domain
            foreach ($IPv4 in $IPv4s.Value.GetEnumerator()) {
                Add-DnsClientDohServerAddress -AllowFallbackToUdp $false -AutoUpgrade $True -ServerAddress $IPv4.Name -DohTemplate $IPv4.Value | Out-Null
            }
        }

        # Loop over IPv6 details
        foreach ($IPv6s in $DoH.Value.GetEnumerator() | Where-Object -FilterScript { $_.name -eq 'IPv6' }) {

            # Loop over each IPv6 address and its DoH domain
            foreach ($IPv6 in $IPv6s.Value.GetEnumerator()) {
                Add-DnsClientDohServerAddress -AllowFallbackToUdp $false -AutoUpgrade $True -ServerAddress $IPv6.Name -DohTemplate $IPv6.Value | Out-Null
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
