# Everything in here applies to the entire module because this file is the root module and loads in the global scope by module manifest

#Requires -RunAsAdministrator

# Stopping the module process if any error occurs
$ErrorActionPreference = 'Stop'

# Set PSReadline tab completion to complete menu for easier access to available parameters - Only for the current session
Set-PSReadLineKeyHandler -Key 'Tab' -Function 'MenuComplete'

# Import sub-modules/functions into global scope that are required for main functions/cmdlets to operate
Import-Module -Name "$WinSecureDNSMgrModuleRootPath\Shared\Get-ActiveNetworkAdapterWinSecureDNS.psm1" -Force -Global
Import-Module -Name "$WinSecureDNSMgrModuleRootPath\Shared\Get-ManualNetworkAdapterWinSecureDNS.psm1" -Force -Global
Import-Module -Name "$WinSecureDNSMgrModuleRootPath\Shared\CommonResources.psm1" -Force -Global
