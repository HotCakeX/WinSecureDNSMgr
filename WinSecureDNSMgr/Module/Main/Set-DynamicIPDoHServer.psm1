function Set-DynamicIPDoHServer {
  [Alias('Set-DDOH')]
  [CmdletBinding()]
  [OutputType([System.String])]
  param (
    # checking to make sure the DoH template is valid and not one of the built-in ones
    [ValidatePattern('^https\:\/\/.+\..+\/.*', ErrorMessage = 'The value provided for the parameter DoHTemplate is not a valid DNS over HTTPS template. Please enter a valid DNS over HTTPS template that starts with https, has a TLD and a slash after it. E.g.: https://template.com/')]
    [ValidateScript({ $_ -notmatch 'https://(cloudflare-dns|dns\.google|dns\.quad9)\.com/dns-query' }, ErrorMessage = 'The DoH template you selected is one of the Windows built-in ones. Please select a different DoH template or use the Set-BuiltInWinSecureDNS cmdlet.')]
    [Parameter(Mandatory)][System.String]$DoHTemplate
  )

  begin {
    # Detecting if Verbose switch is used
    [System.Boolean]$Verbose = $PSBoundParameters.Verbose.IsPresent ? $true : $false

    # Importing the $PSDefaultParameterValues to the current session, prior to everything else
    . "$WinSecureDNSMgrModuleRootPath\MainExt\PSDefaultParameterValues.ps1"

    # Importing the required sub-modules
    Import-Module -Name "$WinSecureDNSMgrModuleRootPath\Shared\Get-ActiveNetworkAdapterWinSecureDNS.psm1" -Force
    Import-Module -Name "$WinSecureDNSMgrModuleRootPath\Shared\Get-IPv6DoHServerIPAddressWinSecureDNSMgr.psm1" -Force
    Import-Module -Name "$WinSecureDNSMgrModuleRootPath\Shared\Get-IPv4DoHServerIPAddressWinSecureDNSMgr.psm1" -Force

    # This service shouldn't be disabled
    # https://github.com/HotCakeX/WinSecureDNSMgr/issues/7
    if (!((Get-Service -Name 'Dnscache').StartType -ne 'Disabled')) {
      throw 'The DNS Client service status is disabled. Please start the service and try again.'
    }

    # Define the regex for extracting the domain name
    [System.String]$DomainExtractionRegex = '(?<=https\:\/\/).+?(?=\/)'

    # Test if the input matches the regex
    $DoHTemplate -match $DomainExtractionRegex | Out-Null
    # Access the matched value
    [System.String]$Domain = $Matches[0]

    Write-Verbose -Message "The extracted domain name is $Domain"

  }

  process {

    [Microsoft.Management.Infrastructure.CimInstance]$ActiveNetworkInterface = Get-ActiveNetworkAdapterWinSecureDNS
    Write-Host -Object 'This is the final detected network adapter this module is going to set Secure DNS for' -ForegroundColor DarkMagenta
    $ActiveNetworkInterface

    # check if there is any IP address already associated with "$DoHTemplate" template
    $OldIPs = (Get-DnsClientDohServerAddress | Where-Object { $_.dohTemplate -eq $DoHTemplate }).ServerAddress
    # if there is, remove them
    if ($OldIPs) {
      $OldIPs | ForEach-Object -Process {
        Remove-DnsClientDohServerAddress -ServerAddress $_
      }
    }

    # reset the network adapter's DNS servers back to default to take care of any IPv6 strays
    Set-DnsClientServerAddress -InterfaceIndex $ActiveNetworkInterface.ifIndex -ResetServerAddresses

    # delete all other previous DoH settings for ALL Interface - Windows behavior in settings when changing DoH settings is to delete all DoH settings for the interface we are modifying
    # but we need to delete all DoH settings for ALL interfaces in here because every time we virtualize a network adapter with external switch of Hyper-V,
    # Hyper-V assigns a new GUID to it, so it's better not to leave any leftover in the registry and clean up after ourselves
    Remove-Item -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\*' -Recurse

    Write-Verbose -Message 'Getting the new IPv4s for the selected DoH server'
    [System.String[]]$NewIPsV4 = Get-IPv4DoHServerIPAddressWinSecureDNSMgr -Domain $Domain

    if ($null -ne $NewIPsV4) {

      Write-Verbose -Message "The new IPv4s are $NewIPsV4"

      # loop over each IPv4
      $NewIPsV4 | ForEach-Object -Process {

        # defining registry path for DoH settings of the $ActiveNetworkInterface based on its GUID for IPv4
        [System.String]$PathV4 = "Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\$($ActiveNetworkInterface.InterfaceGuid)\DohInterfaceSettings\Doh\$_"

        Write-Verbose -Message 'Associating the new IPv4s with the selected DoH template in Windows DoH template predefined list'
        $null = Add-DnsClientDohServerAddress -ServerAddress $_ -DohTemplate $DoHTemplate -AllowFallbackToUdp $False -AutoUpgrade $True

        # add DoH settings for the specified Network adapter based on its GUID in registry
        # value 1 for DohFlags key means use automatic template for DoH, 2 means manual template, since we add our template to Windows, it's predefined so we use value 1
        $null = New-Item -Path $PathV4 -Force
        $null = New-ItemProperty -Path $PathV4 -Name 'DohFlags' -Value '1' -PropertyType 'Qword' -Force
      }
    }
    else {
      Write-Verbose -Message 'IPv4s could not be found for the domain'
    }

    Write-Verbose -Message 'Getting the new IPv6s for the selected DoH server'
    [System.String[]]$NewIPsV6 = Get-IPv6DoHServerIPAddressWinSecureDNSMgr -Domain $Domain

    if ($null -ne $NewIPsV6) {

      Write-Verbose -Message "The new IPv6s are $NewIPsV6"

      # loop over each IPv6
      $NewIPsV6 | ForEach-Object -Process {

        # defining registry path for DoH settings of the $ActiveNetworkInterface based on its GUID for IPv6
        [System.String]$PathV6 = "Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\$($ActiveNetworkInterface.InterfaceGuid)\DohInterfaceSettings\Doh6\$_"

        Write-Verbose -Message 'Associating the new IPv6s with the selected DoH template in Windows DoH template predefined list'
        $null = Add-DnsClientDohServerAddress -ServerAddress $_ -DohTemplate $DoHTemplate -AllowFallbackToUdp $False -AutoUpgrade $True

        # add DoH settings for the specified Network adapter based on its GUID in registry
        # value 1 for DohFlags key means use automatic template for DoH, 2 means manual template, since we already added our template to Windows, it's considered predefined, so we use value 1
        $null = New-Item -Path $PathV6 -Force
        $null = New-ItemProperty -Path $PathV6 -Name 'DohFlags' -Value '1' -PropertyType 'Qword' -Force
      }
    }
    else {
      Write-Verbose -Message 'IPv6s could not be found for the domain'
    }

    # If there are any IPv4 or IPv6, gather them all in one place
    if ($NewIPsV4 -or $NewIPsV6) {
      [System.String[]]$NewIPs = $NewIPsV4 + $NewIPsV6
    }
    else {
      Throw 'No IPv4 or IPv6 could be found for the domain'
    }

    # this is responsible for making the changes in Windows settings UI > Network and internet > $ActiveNetworkInterface.Name
    Set-DnsClientServerAddress -ServerAddresses $NewIPs -InterfaceIndex $ActiveNetworkInterface.ifIndex

    Write-Verbose -Message 'Clearing the DNS client cache'
    Clear-DnsClientCache
  }

  End {

    Write-Verbose -Message 'Enabling the DNS Client event log and setting its log size to 2MB'
    [System.String]$LogName = 'Microsoft-Windows-DNS-Client/Operational'
    [System.Diagnostics.Eventing.Reader.EventLogConfiguration]$Log = New-Object -TypeName System.Diagnostics.Eventing.Reader.EventLogConfiguration -ArgumentList $LogName
    $Log.MaximumSizeInBytes = 2048000
    $Log.IsEnabled = $True
    $Log.SaveChanges()

    Write-Verbose -Message 'Creating the scheduled task'
    [Microsoft.Management.Infrastructure.CimInstance]$Action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument "-executionPolicy bypass -command `"Set-DynamicIPDoHServer -DoHTemplate '$DoHTemplate'`""

    [Microsoft.Management.Infrastructure.CimInstance]$TaskPrincipal = New-ScheduledTaskPrincipal -LogonType S4U -UserId $env:USERNAME -RunLevel Highest

    Write-Verbose -Message 'Creating the 1st trigger - Fires the task when DNS Client event logs indicate the DNS servers are unreachable'
    [Microsoft.Management.Infrastructure.CimClass]$CIMTriggerClass = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler:MSFT_TaskEventTrigger

    [Microsoft.Management.Infrastructure.CimInstance]$EventTrigger = New-CimInstance -CimClass $CIMTriggerClass -ClientOnly

    $EventTrigger.Subscription =
    @'
<QueryList><Query Id="0" Path="Microsoft-Windows-DNS-Client/Operational"><Select Path="Microsoft-Windows-DNS-Client/Operational">*[System[Provider[@Name='Microsoft-Windows-DNS-Client'] and EventID=1013]]</Select></Query></QueryList>
'@
    $EventTrigger.Enabled = $True
    $EventTrigger.ExecutionTimeLimit = 'PT1M'

    Write-Verbose -Message 'Creating the 2nd trigger - Fires the task once in 3 hours with repetition intervals of every 6 hours (with a random delay of 30 seconds)'
    [Microsoft.Management.Infrastructure.CimInstance]$Time = New-ScheduledTaskTrigger -Once -At (Get-Date).AddHours(3) -RandomDelay (New-TimeSpan -Seconds 30) -RepetitionInterval (New-TimeSpan -Hours 6)
    Register-ScheduledTask -Action $Action -Trigger $EventTrigger, $Time -Principal $TaskPrincipal -TaskPath 'DDoH' -TaskName 'Dynamic DoH Server IP check' -Description 'Checks for New IPs of our Dynamic DoH server' -Force | Out-Null

    # define advanced settings for the task
    [Microsoft.Management.Infrastructure.CimInstance]$TaskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Compatibility Win8 -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 1)

    # add advanced settings we defined to the task
    Set-ScheduledTask -TaskPath 'DDoH' -TaskName 'Dynamic DoH Server IP check' -Settings $TaskSettings | Out-Null

  }

  <#
.SYNOPSIS
  Use a DNS over HTTPS (DoH) server with a dynamic IP address in Windows
.LINK
  https://github.com/HotCakeX/WinSecureDNSMgr
.DESCRIPTION
  Easily use a DNS over HTTPS (DoH) server with a dynamic IP address in Windows
.FUNCTIONALITY
  Sets a DNS over HTTPS (DoH) server in Windows DNS client settings and adds the DoH server to the Windows DoH template predefined list.
  It then updates the DoH server IP address in Windows DNS client settings whenever the IP address of the DoH server changes.
.PARAMETER DoHTemplate
  The DNS over HTTPS template of the server that has a dynamic IP address
.PARAMETER Verbose
  Switch to enable verbose output
.EXAMPLE
  Set-DDOH -DoHTemplate https://example.com/
  Set-DynamicIPDoHServer -DoHTemplate https://example.com/
.INPUTS
  System.String
.OUTPUTS
  System.String
#>
}
