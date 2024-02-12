Function Reset-DoHSettings {
    [CmdletBinding()]
    param()

    Write-Verbose -Message 'Displaying non-system DoH templates.'
    Get-DnsClientDohServerAddress | Where-Object -FilterScript { $_.DohTemplate -notin $BuiltInDoHTemplatesReference.Values.Values.Values } |
    ForEach-Object -Process {
        Write-Verbose -Message "Non-System DoH template with the Server Address $($_.ServerAddress) and Domain $($_.DohTemplate) detected."
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
                Add-DnsClientDohServerAddress -AllowFallbackToUdp $false -AutoUpgrade $true -ServerAddress $IPv4.Name -DohTemplate $IPv4.Value
            }
        }

        # Loop over IPv6 details
        foreach ($IPv6s in $DoH.Value.GetEnumerator() | Where-Object -FilterScript { $_.name -eq 'IPv6' }) {

            # Loop over each IPv6 address and its DoH domain
            foreach ($IPv6 in $IPv6s.Value.GetEnumerator()) {
                Add-DnsClientDohServerAddress -AllowFallbackToUdp $false -AutoUpgrade $true -ServerAddress $IPv6.Name -DohTemplate $IPv6.Value
            }
        }
    }

    <#
.SYNOPSIS
    First removes all of the saved DoH templates from the system and then restores back the defaults
.INPUTS
    None
.OUTPUTS
    System.Void
#>
}
