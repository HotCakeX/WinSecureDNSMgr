# Functions to write in custom colors using PSStyle
function WriteViolet { Write-Host -Object "$($PSStyle.Foreground.FromRGB(153,0,255))$($args[0])$($PSStyle.Reset)" -NoNewline }
function WritePink { Write-Host -Object "$($PSStyle.Foreground.FromRGB(255,0,230))$($args[0])$($PSStyle.Reset)" -NoNewline }
function WriteLavender { Write-Host -Object "$($PSStyle.Foreground.FromRgb(255,179,255))$($args[0])$($PSStyle.Reset)" -NoNewline }
function WriteTeaGreen { Write-Host -Object "$($PSStyle.Foreground.FromRgb(133, 222, 119))$($args[0])$($PSStyle.Reset)" -NoNewline }

Export-ModuleMember -Function 'WriteViolet', 'WritePink', 'WriteLavender', 'WriteTeaGreen'
