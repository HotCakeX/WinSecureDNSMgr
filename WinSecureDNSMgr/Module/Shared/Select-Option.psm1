function Select-Option {
    param(
        [parameter(Mandatory = $True, Position = 0)][System.String]$Message,
        [parameter(Mandatory = $True, Position = 1)][System.String[]]$Options
    )
    Begin {
        $Selected = $null
    }

    Process {
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
    }
    End {
        return $Selected
    }
}
Export-ModuleMember -Function 'Select-Option'
