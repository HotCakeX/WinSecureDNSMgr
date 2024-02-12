function Get-ManualNetworkAdapterWinSecureDNS {
    [CmdletBinding()]
    [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
    param()
    <#
.SYNOPSIS
    Displays a table of network adapters and prompts the user to select one of them
    If user cancels the operation then display an error which is interpreted as a terminating error due to the global Error Action Preference
.INPUTS
    None
.OUTPUTS
    Microsoft.Management.Infrastructure.CimInstance
    Returns the selected network adapter as a CimInstance
#>

    Begin {
        # Importing the $PSDefaultParameterValues to the current session, prior to everything else
        . "$WinSecureDNSMgrModuleRootPath\MainExt\PSDefaultParameterValues.ps1"

        # Import the required modules
        Import-Module -Name "$WinSecureDNSMgrModuleRootPath\Shared\ColorFunctions.psm1" -Force
    }

    Process {
        
        # Get the network adapters and their properties if their status is neither disabled, disconnected nor null
        [System.Object[]]$Adapters = Get-NetAdapter | Where-Object -FilterScript {
        ($_.Status -ne 'Disabled') -and ($null -ne $_.Status) -and ($_.Status -ne 'Disconnected')
        }

        # Get the maximum length of each property for formatting the output
        [System.UInt32]$NameLength = ($Adapters.Name | Measure-Object -Maximum -Property Length).Maximum + 2
        [System.UInt32]$DescriptionLength = ($Adapters.InterfaceDescription | Measure-Object -Maximum -Property Length).Maximum + 2
        [System.UInt32]$MacLength = ($Adapters.MacAddress | Measure-Object -Maximum -Property Length).Maximum + 2

        # Not used because manually setting the width for it
        # $StatusLength = ($Adapters.Status | Measure-Object -Maximum -Property Length).Maximum + 2
        [System.UInt32]$LinkLength = ($Adapters.LinkSpeed | Measure-Object -Maximum -Property Length).Maximum + 2

        # Creating a heading for the columns
        # Write the index of the adapter
        WriteLavender ('{0,-5}' -f '#')

        # Write the name of the adapter in cyan
        WriteTeaGreen ("|{0,-$NameLength}" -f 'Name')

        # Write the interface description of the adapter in yellow
        WritePink ("|{0,-$DescriptionLength}" -f 'Description')

        # Write the MAC address of the adapter in green
        WriteViolet ("|{0,-$MacLength}" -f 'Mac Addr')

        # Write the status of the adapter in red
        Write-Host -Object ('|{0,-8}' -f 'Status') -NoNewline -ForegroundColor Red

        # Write the link speed of the adapter in magenta
        Write-Host -Object ("|{0,-$LinkLength}" -f 'Speed') -ForegroundColor Magenta

        # Loop through the adapters and display them in a table with colors
        for ($i = 0; $i -lt $Adapters.Count; $i++) {

            # Write the index of the adapter
            WriteLavender ('{0,-5}' -f ($i + 1))

            # Write the name of the adapter in cyan
            WriteTeaGreen ("|{0,-$NameLength}" -f $Adapters[$i].Name)

            # Write the interface description of the adapter in yellow
            WritePink ("|{0,-$DescriptionLength}" -f $Adapters[$i].InterfaceDescription)

            # Write the MAC address of the adapter in green
            WriteViolet ("|{0,-$MacLength}" -f $Adapters[$i].MacAddress)

            # Write the status of the adapter in red
            Write-Host -Object ('|{0,-8}' -f $Adapters[$i].Status) -NoNewline -ForegroundColor Red

            # Write the link speed of the adapter in magenta
            Write-Host -Object ("|{0,-$LinkLength}" -f $Adapters[$i].LinkSpeed) -ForegroundColor Magenta
        }

        # Get the max count of available network adapters and add 1 to it, assign the number as exit value to break the loop when selected
        $ExitCodeAdapterSelection = $Adapters.Count + 1

        # Write an exit option at the end of the table
        Write-Host -Object ('{0,-5}' -f "$ExitCodeAdapterSelection") -NoNewline -ForegroundColor DarkRed
        Write-Host -Object '|Cancel' -ForegroundColor DarkRed

        # Define a function to validate the user input
        function Confirm-Choice {
            param($Choice)

            # Get an array of valid numbers from 1 to $ExitCodeAdapterSelection
            $ValidNumbers = 1..$ExitCodeAdapterSelection

            # Initialize a flag to indicate if the input is valid or not
            [System.Boolean]$IsValid = $false

            # Loop through each valid number and compare it with the input
            foreach ($Number in $ValidNumbers) {
                # If the input is equal to a valid number, set the flag to true and break the loop
                if ($Choice -eq $Number) {
                    $IsValid = $True
                    break
                }
            }
            # Return the flag value
            return $IsValid
        }

        # Prompt the user to enter the number of the adapter they want to select, or exit value to exit, until they enter a valid input
        do {
            $Choice = Read-Host -Prompt "Enter the number of the adapter you want to select or press $ExitCodeAdapterSelection to Cancel`n"

            # Check if the input is valid using the Confirm-Choice function
            if (-not (Confirm-Choice $Choice)) {
                # Write an error message in red if invalid
                Write-Host -Object "Invalid input. Please enter a number between 1 and $ExitCodeAdapterSelection." -ForegroundColor Red
            }
        }
        while (-not (Confirm-Choice $Choice))
    }

    End {
        # Check if the user entered the exit value to break out of the loop
        if ($Choice -eq $ExitCodeAdapterSelection) {
            Write-Error -Message 'User cancelled the operation'
        }
        else {
            # Get the selected adapter from the array and display it
            $ActiveNetworkInterface = $Adapters[$Choice - 1]
            return [Microsoft.Management.Infrastructure.CimInstance]$ActiveNetworkInterface
        }
    }
}
Export-ModuleMember -Function 'Get-ManualNetworkAdapterWinSecureDNS'
