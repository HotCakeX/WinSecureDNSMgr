# Everything in here applies to the entire module because this file is the root module and loads in the global scope by module manifest

#Requires -RunAsAdministrator

# Stopping the module process if any error occurs - it it important for this to be global, otherwise it won't apply to the entire module
$global:ErrorActionPreference = 'Stop'

# Set PSReadline tab completion to complete menu for easier access to available parameters - Only for the current session
Set-PSReadLineKeyHandler -Key 'Tab' -Function 'MenuComplete'
