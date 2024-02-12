Function Invoke-cURL {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.String]$Url
    )
    <#
    .SYNOPSIS
        we use --ssl-no-revoke because when system DNS is unreachable, CRL check will fail in cURL.
        it is OKAY, we're using trusted Cloudflare and Google servers the certificates of which explicitly mention their IP addresses (in Subject Alternative Name) that we are using to connect to them
    #>

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
Export-ModuleMember -Function 'Invoke-cURL'
