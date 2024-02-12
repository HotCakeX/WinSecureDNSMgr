Function Get-DoHIPs {
    [CmdletBinding()]
    [OutputType([System.Net.IPAddress[]])]
    param (
        [Parameter(Mandatory)]
        [System.String]$Url
    )
    <#
    .SYNOPSIS
        Using -SkipCertificateCheck because when system DNS is unreachable, CRL check will fail
        However, since directly using trusted IP addresses of Cloudflare and Google servers, the certificates of which explicitly mention their IP addresses (in Subject Alternative Name) that we are using to connect to, it's safe to skip the certificate check
    .PARAMETER Url
        The URL to query for DNS records
    .INPUTS
        System.String
    .OUTPUTS
        System.Net.IPAddress[]
    #>

    Begin {
        # Importing the $PSDefaultParameterValues to the current session, prior to everything else
        . "$WinSecureDNSMgrModuleRootPath\MainExt\PSDefaultParameterValues.ps1"
    }

    Process {
        $IPs = Invoke-RestMethod -Uri $Url -Method Get -Headers @{'accept' = 'application/dns-json' } -SkipCertificateCheck

        # Only extract the IP address, sometimes the response contains other data such as texts
        [System.Net.IPAddress[]]$IPs = $IPs.answer.data | Where-Object -FilterScript { [System.Net.IPAddress]::TryParse($_ , [ref]$null) }
    }

    End {
        return $IPs
    }
}
Export-ModuleMember -Function 'Get-DoHIPs'
