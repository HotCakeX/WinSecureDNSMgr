# This file is for launching WinSecureDNSMgr module in VS Code so that it can attach its debugger to the process

# Get the current folder of this script file
[System.String]$ScriptFilePath = ($MyInvocation.MyCommand.path | Split-Path -Parent)

# Import the module into the current scope using the relative path of the module itself
Import-Module -FullyQualifiedName "$ScriptFilePath\..\Main\WinSecureDNSMgr.psd1" -Force

# Run the commands below
set-doh -DoHProvider Cloudflare