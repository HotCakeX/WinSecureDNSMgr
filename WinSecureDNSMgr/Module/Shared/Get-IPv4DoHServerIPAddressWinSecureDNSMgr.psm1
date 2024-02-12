Function Get-IPv4DoHServerIPAddressWinSecureDNSMgr {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.String]$Domain
    )

    Begin {
        # Importing the $PSDefaultParameterValues to the current session, prior to everything else
        . "$WinSecureDNSMgrModuleRootPath\MainExt\PSDefaultParameterValues.ps1"

        Import-Module -Name "$WinSecureDNSMgrModuleRootPath\Shared\Invoke-cURL.psm1" -Force

        # An array to store IP addresses
        $NewIPsV4 = @()
    }

    Process {
        # get the new IPv4s for $Domain
        Write-Host -Object "Using the main Cloudflare Encrypted API to resolve $Domain" -ForegroundColor Green
        $NewIPsV4 = Invoke-cURL -Url "https://1.1.1.1/dns-query?name=$Domain&type=A"

        if (!$NewIPsV4) {
            Write-Host -Object "First try failed, now using the secondary Encrypted Cloudflare API to to get IPv4s for $Domain" -ForegroundColor Blue
            $NewIPsV4 = Invoke-cURL -Url "https://1.0.0.1/dns-query?name=$Domain&type=A"
        }
        if (!$NewIPsV4) {
            Write-Host -Object "Second try failed, now using the main Encrypted Google API to to get IPv4s for $Domain" -ForegroundColor Yellow
            $NewIPsV4 = Invoke-cURL -Url "https://8.8.8.8/resolve?name=$Domain&type=A"
        }
        if (!$NewIPsV4) {
            Write-Host -Object "Third try failed, now using the second Encrypted Google API to to get IPv4s for $Domain" -ForegroundColor DarkRed
            $NewIPsV4 = Invoke-cURL -Url "https://8.8.4.4/resolve?name=$Domain&type=A"
        }
        if (!$NewIPsV4) {
            Write-Host -Object "Fourth try failed, using any available system DNS to get the IPv4s for $Domain" -ForegroundColor Magenta
            $NewIPsV4 = (Resolve-DnsName -Type A -Name "$Domain" -NoHostsFile).ipaddress
        }
    }

    End {
        if ($NewIPsV4) {
            if ($NewIPsV4.count -gt 2) {
                $NewIPsV4 = $NewIPsV4 | Select-Object -First 2
            }
            return $NewIPsV4
        }
        else {
            Write-Host -Object "Failed to get IPv4s for $Domain" -ForegroundColor Red
            return $null
        }
    }
}
Export-ModuleMember -Function 'Get-IPv4DoHServerIPAddressWinSecureDNSMgr'
