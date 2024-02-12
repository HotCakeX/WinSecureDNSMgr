# Functions for custom color writing
function WriteViolet { Write-Host -Object "$($PSStyle.Foreground.FromRGB(153,0,255))$($args[0])$($PSStyle.Reset)" -NoNewline }
function WritePink { Write-Host -Object "$($PSStyle.Foreground.FromRGB(255,0,230))$($args[0])$($PSStyle.Reset)" -NoNewline }
function WriteLavender { Write-Host -Object "$($PSStyle.Foreground.FromRgb(255,179,255))$($args[0])$($PSStyle.Reset)" -NoNewline }
function WriteTeaGreen { Write-Host -Object "$($PSStyle.Foreground.FromRgb(133, 222, 119))$($args[0])$($PSStyle.Reset)" -NoNewline }


function Select-Option {
    param(
        [parameter(Mandatory = $True, Position = 0)][System.String]$Message,
        [parameter(Mandatory = $True, Position = 1)][System.String[]]$Options
    )
    $Selected = $null
    while ($null -eq $Selected) {

        Write-Host -Object $Message -ForegroundColor Magenta

        for ($i = 0; $i -lt $Options.Length; $i++) {
            Write-Host -Object "$($i+1): $($Options[$i])"
        }
        $SelectedIndex = Read-Host -Prompt 'Select an option'

        if ($SelectedIndex -gt 0 -and $SelectedIndex -le $Options.Length) {
            $Selected = $Options[$SelectedIndex - 1]
        }
        else {
            Write-Host -Object 'Invalid Option.' -ForegroundColor Yellow
        }
    }
    return $Selected
}


# we use --ssl-no-revoke because when system DNS is unreachable, CRL check will fail in cURL.
# it is OKAY, we're using trusted Cloudflare and Google servers the certificates of which explicitly mention their IP addresses (in Subject Alternative Name) that we are using to connect to them
Function Invoke-cURL {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.String]$Url
    )

    # Enables "TLS_CHACHA20_POLY1305_SHA256" Cipher Suite for Windows 11, if necessary, because it's disabled by default
    # cURL will need that cipher suite to perform encrypted DNS query, it uses Windows Schannel
    if (-NOT ((Get-TlsCipherSuite).name -contains 'TLS_CHACHA20_POLY1305_SHA256')) { 
        Write-Verbose -Message 'Enabling TLS_CHACHA20_POLY1305_SHA256 Cipher Suite' -Verbose
        Enable-TlsCipherSuite -Name 'TLS_CHACHA20_POLY1305_SHA256'
    }

    $IPs = curl --ssl-no-revoke --max-time 10 --tlsv1.3 --tls13-ciphers TLS_CHACHA20_POLY1305_SHA256 --http2 -H 'accept: application/dns-json' $Url
    $IPs = ( $IPs | ConvertFrom-Json).answer.data
    return $IPs
}

Function Get-IPv4DoHServerIPAddressWinSecureDNSMgr {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.String]$Domain
    )

    Begin {
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

Function Get-IPv6DoHServerIPAddressWinSecureDNSMgr {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.String]$Domain
    )

    Begin {
        # An array to store IP addresses
        $NewIPsV6 = @()
    }

    Process {
        # get the new IPv6s for $Domain
        Write-Host -Object "Using the main Cloudflare Encrypted API to resolve $Domain" -ForegroundColor Green

        $NewIPsV6 = Invoke-cURL -Url "https://1.1.1.1/dns-query?name=$Domain&type=AAAA"

        if (!$NewIPsV6) {
            Write-Host -Object "First try failed, now using the secondary Encrypted Cloudflare API to to get IPv6s for $Domain" -ForegroundColor Blue
            $NewIPsV6 = Invoke-cURL -Url "https://1.0.0.1/dns-query?name=$Domain&type=AAAA"
        }
        if (!$NewIPsV6) {
            Write-Host -Object "Second try failed, now using the main Encrypted Google API to to get IPv6s for $Domain" -ForegroundColor Yellow
            $NewIPsV6 = Invoke-cURL -Url "https://8.8.8.8/resolve?name=$Domain&type=AAAA"
        }
        if (!$NewIPsV6) {
            Write-Host -Object "Third try failed, now using the second Encrypted Google API to to get IPv6s for $Domain" -ForegroundColor DarkRed
            $NewIPsV6 = Invoke-cURL -Url "https://8.8.4.4/resolve?name=$Domain&type=AAAA"
        }
        if (!$NewIPsV6) {
            Write-Host -Object "Fourth try failed, using any available system DNS to get the IPv6s for $Domain" -ForegroundColor Magenta
            $NewIPsV6 = (Resolve-DnsName -Type AAAA -Name "$Domain" -NoHostsFile).ipaddress
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
