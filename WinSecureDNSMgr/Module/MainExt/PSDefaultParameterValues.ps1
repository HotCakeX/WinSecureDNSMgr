# $PSDefaultParameterValues only get read from scope where invocation occurs
# This is why this file is dot-sourced in every other component of the WinSecureDNSMgr module at the beginning
$PSDefaultParameterValues = @{
    'Invoke-WebRequest:HttpVersion'                     = '3.0'
    'Invoke-WebRequest:SslProtocol'                     = 'Tls13'
    'Invoke-RestMethod:HttpVersion'                     = '3.0'
    'Invoke-RestMethod:SslProtocol'                     = 'Tls13'
    'Invoke-RestMethod:Verbose'                         = $false
    'Invoke-WebRequest:Verbose'                         = $false
    'Import-Module:Verbose'                             = $false
    'Export-ModuleMember:Verbose'                       = $false
    'Set-ScheduledTask:Verbose'                         = $false
    'Register-ScheduledTask:Verbose'                    = $false
    'New-CimInstance:Verbose'                           = $false
    'Get-CimClass:Verbose'                              = $false
    'Get-ActiveNetworkAdapterWinSecureDNS:Verbose'      = $Verbose
    'Get-ManualNetworkAdapterWinSecureDNS:Verbose'      = $Verbose
    'Get-IPv4DoHServerIPAddressWinSecureDNSMgr:Verbose' = $Verbose
    'Get-IPv6DoHServerIPAddressWinSecureDNSMgr:Verbose' = $Verbose
    'Select-Option:Verbose'                             = $Verbose
    'Get-DoHIPs:Verbose'                                = $Verbose
}
