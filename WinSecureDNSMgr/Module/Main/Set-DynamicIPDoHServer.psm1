function Set-DynamicIPDoHServer {
  [Alias('Set-DDOH')]
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    # checking to make sure the DoH template is valid and not one of the built-in ones
    [ValidatePattern('^https\:\/\/.+\..+\/.*', ErrorMessage = 'The value provided for the parameter DoHTemplate is not a valid DNS over HTTPS template. Please enter a valid DNS over HTTPS template that starts with https, has a TLD and a slash after it. E.g.: https://template.com/')]
    [ValidateScript({ $_ -notmatch 'https://(cloudflare-dns|dns\.google|dns\.quad9)\.com/dns-query' }, ErrorMessage = 'The DoH template you selected is one of the Windows built-in ones. Please select a different DoH template or use the Set-BuiltInWinSecureDNS cmdlet.')]
    [Parameter(Mandatory)][System.String]$DoHTemplate
  )

  begin {

    # Define the regex for extracting the domain name
    $DomainExtractionRegex = '(?<=https\:\/\/).+?(?=\/)'

    # Test if the input matches the regex
    $DoHTemplate -match $DomainExtractionRegex
    # Access the matched value
    $domain = $Matches[0]

    Write-Debug -Message "The extracted domain name is $domain`n"

  }

  process {

    # error handling for the entire function - to make sure there is no error before attempting to create the scheduled task
    try {

      $ActiveNetworkInterface = Get-ActiveNetworkAdapterWinSecureDNS
      Write-Host 'This is the final detected network adapter this module is going to set Secure DNS for' -ForegroundColor DarkMagenta
      $ActiveNetworkInterface

      # check if there is any IP address already associated with "$DoHTemplate" template
      $oldIPs = (Get-DnsClientDohServerAddress | Where-Object { $_.dohTemplate -eq $DoHTemplate }).serveraddress
      # if there is, remove them
      if ($oldIPs) {
        $oldIPs | ForEach-Object {
          Remove-DnsClientDohServerAddress -ServerAddress $_
        }
      }

      # reset the network adapter's DNS servers back to default to take care of any IPv6 strays
      Set-DnsClientServerAddress -InterfaceIndex $ActiveNetworkInterface.ifIndex -ResetServerAddresses

      # delete all other previous DoH settings for ALL Interface - Windows behavior in settings when changing DoH settings is to delete all DoH settings for the interface we are modifying
      # but we need to delete all DoH settings for ALL interfaces in here because every time we virtualize a network adapter with external switch of Hyper-V,
      # Hyper-V assigns a new GUID to it, so it's better not to leave any leftover in the registry and clean up after ourselves
      Remove-Item 'HKLM:System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\*' -Recurse

      [string[]]$NewIPsV4 = Get-IPv4DoHServerIPAddressWinSecureDNSMgr -Domain $domain

      # loop through each IPv4
      $NewIPsV4 | ForEach-Object {
        # defining registry path for DoH settings of the $ActiveNetworkInterface based on its GUID for IPv4
        $Path = "HKLM:System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\$($ActiveNetworkInterface.InterfaceGuid)\DohInterfaceSettings\Doh\$_"
        # associating the new IPv4s with our DoH template in Windows DoH template predefined list
        Add-DnsClientDohServerAddress -ServerAddress $_ -DohTemplate $DoHTemplate -AllowFallbackToUdp $False -AutoUpgrade $True
        # add DoH settings for the specified Network adapter based on its GUID in registry
        # value 1 for DohFlags key means use automatic template for DoH, 2 means manual template, since we add our template to Windows, it's predefined so we use value 1
        New-Item -Path $Path -Force | Out-Null
        New-ItemProperty -Path $Path -Name 'DohFlags' -Value 1 -PropertyType Qword -Force
      }

      [string[]]$NewIPsV6 = Get-IPv6DoHServerIPAddressWinSecureDNSMgr -Domain $domain

      # loop through each IPv6
      $NewIPsV6 | ForEach-Object {
        # defining registry path for DoH settings of the $ActiveNetworkInterface based on its GUID for IPv6
        $Path = "HKLM:System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\$($ActiveNetworkInterface.InterfaceGuid)\DohInterfaceSettings\Doh6\$_"
        # associating the new IPv6s with our DoH template in Windows DoH template predefined list
        Add-DnsClientDohServerAddress -ServerAddress $_ -DohTemplate $DoHTemplate -AllowFallbackToUdp $False -AutoUpgrade $True
        # add DoH settings for the specified Network adapter based on its GUID in registry
        # value 1 for DohFlags key means use automatic template for DoH, 2 means manual template, since we already added our template to Windows, it's considered predefined, so we use value 1
        New-Item -Path $Path -Force | Out-Null
        New-ItemProperty -Path $Path -Name 'DohFlags' -Value 1 -PropertyType Qword -Force
      }

      # gather IPv4s and IPv6s all in one place
      [string[]]$NewIPs = $NewIPsV4 + $NewIPsV6

      # this is responsible for making the changes in Windows settings UI > Network and internet > $ActiveNetworkInterface.Name
      Set-DnsClientServerAddress -ServerAddresses $NewIPs -InterfaceIndex $ActiveNetworkInterface.ifIndex
      # clear DNS client Cache
      Clear-DnsClientCache
    }

    catch {
      Write-Host 'These errors occured after running the module' -ForegroundColor white
      $_
      $ModuleErrors = $_
    }

  }

  end {

    # here we enable logging for the event log below (which is disabled by default) and set its log size from the default 1MB to 2MB
    $LogName = 'Microsoft-Windows-DNS-Client/Operational'

    $Log = New-Object System.Diagnostics.Eventing.Reader.EventLogConfiguration $LogName
    $Log.MaximumSizeInBytes = 2048000
    $Log.IsEnabled = $true
    $Log.SaveChanges()
    if (!$ModuleErrors) {

      Write-Debug "No errors occured when running the module, creating the scheduled task now if it's not already been created"

      # create a scheduled task
      $Action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument "-executionPolicy bypass -command `"Set-DynamicIPDoHServer -DoHTemplate '$DoHTemplate'`""
      $TaskPrincipal = New-ScheduledTaskPrincipal -LogonType S4U -UserId $env:USERNAME -RunLevel Highest
      # trigger 1
      $CIMTriggerClass =
      Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler:MSFT_TaskEventTrigger
      $EventTrigger = New-CimInstance -CimClass $CIMTriggerClass -ClientOnly
      $EventTrigger.Subscription =
      @'
<QueryList><Query Id="0" Path="Microsoft-Windows-DNS-Client/Operational"><Select Path="Microsoft-Windows-DNS-Client/Operational">*[System[Provider[@Name='Microsoft-Windows-DNS-Client'] and EventID=1013]]</Select></Query></QueryList>
'@
      $EventTrigger.Enabled = $True
      $EventTrigger.ExecutionTimeLimit = 'PT1M'
      # trigger 2
      $Time =
      New-ScheduledTaskTrigger `
        -Once -At (Get-Date).AddHours(3) `
        -RandomDelay (New-TimeSpan -Seconds 30) `
        -RepetitionInterval (New-TimeSpan -Hours 6) `
        # register the task
        Register-ScheduledTask -Action $Action -Trigger $EventTrigger, $Time -Principal $TaskPrincipal -TaskPath 'DDoH' -TaskName 'Dynamic DoH Server IP check' -Description 'Checks for New IPs of our Dynamic DoH server' -Force
      # define advanced settings for the task
      $TaskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Compatibility Win8 -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 1)
      # add advanced settings we defined to the task
      Set-ScheduledTask -TaskPath 'DDoH' -TaskName 'Dynamic DoH Server IP check' -Settings $TaskSettings

    }
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

.EXAMPLE
Set-DDOH -DoHTemplate https://example.com/
Set-DynamicIPDoHServer -DoHTemplate https://example.com/

#>
}
