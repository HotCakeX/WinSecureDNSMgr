Function Remove-ExcessDoHTemplates {
    [CmdletBinding()]
    [OutputType([System.Void])]
    param()

    Get-DnsClientDohServerAddress | Where-Object -FilterScript { $_.DohTemplate -notin $BuiltInDoHTemplatesReference.Values.Values.Values } |
    ForEach-Object -Process {
        Write-Verbose -Message "Removing DoH Template with the Server Address $($_.ServerAddress) and Domain $($_.DohTemplate)"
        Remove-DnsClientDohServerAddress -InputObject $_
    }
    <#
.SYNOPSIS
    Uses the $BuiltInDoHTemplatesReference ordered hashtable as a reference to detect the foreign DoH Templates
    That are saved in Windows and removes them.
.INPUTS
    None
.OUTPUTS
    System.Void
#>
}
