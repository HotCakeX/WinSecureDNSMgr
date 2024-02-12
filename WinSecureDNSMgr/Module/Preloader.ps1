if (!$IsWindows) {
    Throw [System.PlatformNotSupportedException] 'The module only runs on Windows operation systems.'
}

# Create tamper resistant global variables (if they don't already exist) - They are automatically imported in the caller's environment
try {
    if ((Test-Path -Path 'Variable:\WinSecureDNSMgrModuleRootPath') -eq $false) { New-Variable -Name 'WinSecureDNSMgrModuleRootPath' -Value ($PSScriptRoot) -Option 'Constant' -Scope 'Global' -Description 'Storing the value of $PSScriptRoot in a global constant variable to allow the internal functions to use it when navigating the module structure' -Force }
}
catch {
    Throw [System.InvalidOperationException] 'Could not set the required global variables.'
}

# Get the JSON file containing the DoH reference
[System.String]$BuiltInDoHTemplatesReferenceJSON = Get-Content -Path "$WinSecureDNSMgrModuleRootPath\Shared\BuiltInDoHTemplatesReference.json"

# Convert the JSON content to hashtable and make it available to the entire module
$BuiltInDoHTemplatesReference = ConvertFrom-Json -AsHashtable -InputObject $BuiltInDoHTemplatesReferenceJSON
