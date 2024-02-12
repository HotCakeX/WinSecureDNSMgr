# Functions for custom color writing
function WriteViolet { Write-Host -Object "$($PSStyle.Foreground.FromRGB(153,0,255))$($args[0])$($PSStyle.Reset)" -NoNewline }
function WritePink { Write-Host -Object "$($PSStyle.Foreground.FromRGB(255,0,230))$($args[0])$($PSStyle.Reset)" -NoNewline }
function WriteLavender { Write-Host -Object "$($PSStyle.Foreground.FromRgb(255,179,255))$($args[0])$($PSStyle.Reset)" -NoNewline }
function WriteTeaGreen { Write-Host -Object "$($PSStyle.Foreground.FromRgb(133, 222, 119))$($args[0])$($PSStyle.Reset)" -NoNewline }


function Select-Option {
    param(
        [parameter(Mandatory = $true, Position = 0)][string]$Message,
        [parameter(Mandatory = $true, Position = 1)][string[]]$Options
    )
    $Selected = $null
    while ($null -eq $Selected) {
        Write-Host $Message -ForegroundColor Magenta
        for ($i = 0; $i -lt $Options.Length; $i++) { Write-Host "$($i+1): $($Options[$i])" }
        $SelectedIndex = Read-Host 'Select an option'
        if ($SelectedIndex -gt 0 -and $SelectedIndex -le $Options.Length) { $Selected = $Options[$SelectedIndex - 1] }
        else { Write-Host 'Invalid Option.' -ForegroundColor Yellow }
    }
    return $Selected
}


# we use --ssl-no-revoke because when system DNS is unreachable, CRL check will fail in cURL.
# it is OKAY, we're using trusted Cloudflare and Google servers the certificates of which explicitly mention their IP addresses (in Subject Alternative Name) that we are using to connect to them
Function Invoke-cURL {
    param($url)

    # Enables "TLS_CHACHA20_POLY1305_SHA256" Cipher Suite for Windows 11, if necessary, because it's disabled by default
    # cURL will need that cipher suite to perform encrypted DNS query, it uses Windows Schannel
    if (-NOT ((Get-TlsCipherSuite).name -contains 'TLS_CHACHA20_POLY1305_SHA256'))
    { Enable-TlsCipherSuite -Name 'TLS_CHACHA20_POLY1305_SHA256' }

    $IPs = curl --ssl-no-revoke --max-time 10 --tlsv1.3 --tls13-ciphers TLS_CHACHA20_POLY1305_SHA256 --http2 -H 'accept: application/dns-json' $url
    $IPs = ( $IPs | ConvertFrom-Json).answer.data
    return $IPs
}


# Explicitly defining array type variable to store IP addresses
$NewIPsV4 = @()

Function Get-IPv4DoHServerIPAddressWinSecureDNSMgr {
    param ($domain)

    # get the new IPv4s for $domain
    Write-Host -Object "Using the main Cloudflare Encrypted API to resolve $domain" -ForegroundColor Green
    $NewIPsV4 = Invoke-cURL "https://1.1.1.1/dns-query?name=$domain&type=A"

    if (!$NewIPsV4) {
        Write-Host "First try failed, now using the secondary Encrypted Cloudflare API to to get IPv4s for $domain" -ForegroundColor Blue
        $NewIPsV4 = Invoke-cURL "https://1.0.0.1/dns-query?name=$domain&type=A"
    }
    if (!$NewIPsV4) {
        Write-Host "Second try failed, now using the main Encrypted Google API to to get IPv4s for $domain" -ForegroundColor Yellow
        $NewIPsV4 = Invoke-cURL "https://8.8.8.8/resolve?name=$domain&type=A"
    }
    if (!$NewIPsV4) {
        Write-Host "Third try failed, now using the second Encrypted Google API to to get IPv4s for $domain" -ForegroundColor DarkRed
        $NewIPsV4 = Invoke-cURL "https://8.8.4.4/resolve?name=$domain&type=A"
    }
    if (!$NewIPsV4) {
        Write-Host "Fourth try failed, using any available system DNS to get the IPv4s for $domain" -ForegroundColor Magenta
        $NewIPsV4 = (Resolve-DnsName -Type A -Name "$domain" -NoHostsFile).ipaddress
    }

    if ($NewIPsV4) {
        if ($NewIPsV4.count -gt 2) {
            $NewIPsV4 = $NewIPsV4 | Select-Object -First 2
        }
        return $NewIPsV4
    }
    else {
        Write-Host "`nFailed to get IPv4s for $domain" -ForegroundColor Red
        return $null
    }
}

# Explicitly defining array type variable to store IP addresses
$NewIPsV6 = @()

Function Get-IPv6DoHServerIPAddressWinSecureDNSMgr {
    param ($domain)

    # get the new IPv6s for $domain
    Write-Host "Using the main Cloudflare Encrypted API to resolve $domain" -ForegroundColor Green
    $NewIPsV6 = Invoke-cURL "https://1.1.1.1/dns-query?name=$domain&type=AAAA"

    if (!$NewIPsV6) {
        Write-Host "First try failed, now using the secondary Encrypted Cloudflare API to to get IPv6s for $domain" -ForegroundColor Blue
        $NewIPsV6 = Invoke-cURL "https://1.0.0.1/dns-query?name=$domain&type=AAAA"
    }
    if (!$NewIPsV6) {
        Write-Host "Second try failed, now using the main Encrypted Google API to to get IPv6s for $domain" -ForegroundColor Yellow
        $NewIPsV6 = Invoke-cURL "https://8.8.8.8/resolve?name=$domain&type=AAAA"
    }
    if (!$NewIPsV6) {
        Write-Host "Third try failed, now using the second Encrypted Google API to to get IPv6s for $domain" -ForegroundColor DarkRed
        $NewIPsV6 = Invoke-cURL "https://8.8.4.4/resolve?name=$domain&type=AAAA"
    }
    if (!$NewIPsV6) {
        Write-Host "Fourth try failed, using any available system DNS to get the IPv6s for $domain" -ForegroundColor Magenta
        $NewIPsV6 = (Resolve-DnsName -Type AAAA -Name "$domain" -NoHostsFile).ipaddress
    }

    if ($NewIPsV6) {
        # in case server had more than 2 IP addresses
        if ($NewIPsV6.count -gt 2) {
            $NewIPsV6 = $NewIPsV6 | Select-Object -First 2
        }
        return $NewIPsV6
    }
    else {
        Write-Host "`nFailed to get IPv6s for $domain" -ForegroundColor Red
        return $null
    }
}


# Defining the Built-in DNS templates available in Windows
$BuiltInDoHTemplatesReference = [ordered]@{
    'CloudFlare' = [ordered]@{
        'IPv4' = [ordered]@{
            '1.1.1.1' = 'https://cloudflare-dns.com/dns-query'
            '1.0.0.1' = 'https://cloudflare-dns.com/dns-query'
        }
        'IPv6' = [ordered]@{
            '2606:4700:4700::1111' = 'https://cloudflare-dns.com/dns-query'
            '2606:4700:4700::1001' = 'https://cloudflare-dns.com/dns-query'
        }
    }
    'Quad9'      = [ordered]@{
        'IPv4' = [ordered]@{
            '9.9.9.9'         = 'https://dns.quad9.net/dns-query'
            '149.112.112.112' = 'https://dns.quad9.net/dns-query'

        }
        'IPv6' = [ordered]@{
            '2620:fe::9'  = 'https://dns.quad9.net/dns-query'
            '2620:fe::fe' = 'https://dns.quad9.net/dns-query'
        }
    }
    'Google'     = [ordered]@{
        'IPv4' = [ordered]@{
            '8.8.8.8' = 'https://dns.google/dns-query'
            '8.8.4.4' = 'https://dns.google/dns-query'
        }
        'IPv6' = [ordered]@{
            '2001:4860:4860::8888' = 'https://dns.google/dns-query'
            '2001:4860:4860::8844' = 'https://dns.google/dns-query'
        }
    }
}
