Function Get-IPv6DoHServerIPAddressWinSecureDNSMgr {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.String]$Domain
    )

    Begin {
        # Importing the $PSDefaultParameterValues to the current session, prior to everything else
        . "$WinSecureDNSMgrModuleRootPath\MainExt\PSDefaultParameterValues.ps1"

        # Importing the required sub-modules
        Import-Module -Name "$WinSecureDNSMgrModuleRootPath\Shared\Get-DoHIPs.psm1" -Force

        # An array to store IP addresses
        $NewIPsV6 = @()
    }

    Process {
        # get the new IPv6s for $Domain
        Write-Host -Object "Using the main Cloudflare Encrypted API to resolve $Domain" -ForegroundColor Green

        $NewIPsV6 = Get-DoHIPs -Url "https://1.1.1.1/dns-query?name=$Domain&type=AAAA"

        if (!$NewIPsV6) {
            Write-Host -Object "First try failed, now using the secondary Encrypted Cloudflare API to to get IPv6s for $Domain" -ForegroundColor Blue
            $NewIPsV6 = Get-DoHIPs -Url "https://1.0.0.1/dns-query?name=$Domain&type=AAAA"
        }
        if (!$NewIPsV6) {
            Write-Host -Object "Second try failed, now using the main Encrypted Google API to to get IPv6s for $Domain" -ForegroundColor Yellow
            $NewIPsV6 = Get-DoHIPs -Url "https://8.8.8.8/resolve?name=$Domain&type=AAAA"
        }
        if (!$NewIPsV6) {
            Write-Host -Object "Third try failed, now using the second Encrypted Google API to to get IPv6s for $Domain" -ForegroundColor DarkRed
            $NewIPsV6 = Get-DoHIPs -Url "https://8.8.4.4/resolve?name=$Domain&type=AAAA"
        }
        if (!$NewIPsV6) {
            Write-Host -Object "Fourth try failed, using any available system DNS to get the IPv6s for $Domain" -ForegroundColor Magenta

            try {
                $NewIPsV6 = (Resolve-DnsName -Type AAAA -Name "$Domain" -NoHostsFile).ipaddress
            }
            catch {
                Write-Warning -Message 'Could not find IPv6 for the domain using system DNS'
            }
        }
    }

    End {
        if ($NewIPsV6) {
            # in case server had more than 2 IP addresses
            if ($NewIPsV6.count -gt 2) {
                $NewIPsV6 = $NewIPsV6 | Select-Object -First 2
            }
            return $NewIPsV6
        }
        else {
            Write-Host -Object "Failed to get IPv6s for $Domain" -ForegroundColor Red
            return $null
        }
    }
}
Export-ModuleMember -Function 'Get-IPv6DoHServerIPAddressWinSecureDNSMgr'
