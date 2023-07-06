function Get-ManualNetworkAdapterWinSecureDNS {

    # Get the network adapters and their properties if their status is neither disabled, disconnected nor null
    $Adapters = Get-NetAdapter | Where-Object { $_.Status -ne 'Disabled' -and $null -ne $_.Status -and $_.Status -ne 'Disconnected' }
    # Get the maximum length of each property for formatting the output
    $NameLength = ($Adapters.Name | Measure-Object -Maximum -Property Length).Maximum + 2
    $DescriptionLength = ($Adapters.InterfaceDescription | Measure-Object -Maximum -Property Length).Maximum + 2
    $MacLength = ($Adapters.MacAddress | Measure-Object -Maximum -Property Length).Maximum + 2
    # Not used because manually setting the width for it
    # $StatusLength = ($Adapters.Status | Measure-Object -Maximum -Property Length).Maximum + 2
    $LinkLength = ($Adapters.LinkSpeed | Measure-Object -Maximum -Property Length).Maximum + 2

    # Creating a heading for the columns
    # Write the index of the adapter
    WriteLavender ("{0,-5}" -f "#")
    # Write the name of the adapter in cyan
    WriteTeaGreen ("|{0,-$NameLength}" -f "Name")
    # Write the interface description of the adapter in yellow
    WritePink ("|{0,-$DescriptionLength}" -f "Description")
    # Write the MAC address of the adapter in green
    WriteViolet ("|{0,-$MacLength}" -f "Mac Addr")
    # Write the status of the adapter in red
    Write-Host ("|{0,-8}" -f "Status") -NoNewline -ForegroundColor Red
    # Write the link speed of the adapter in magenta
    Write-Host ("|{0,-$LinkLength}" -f "Speed") -ForegroundColor Magenta

    # Loop through the adapters and display them in a table with colors
    for ($i = 0; $i -lt $Adapters.Count; $i++) {
        # Write the index of the adapter
        WriteLavender ("{0,-5}" -f ($i + 1))
        # Write the name of the adapter in cyan
        WriteTeaGreen ("|{0,-$NameLength}" -f $Adapters[$i].Name)
        # Write the interface description of the adapter in yellow
        WritePink ("|{0,-$DescriptionLength}" -f $Adapters[$i].InterfaceDescription)
        # Write the MAC address of the adapter in green
        WriteViolet ("|{0,-$MacLength}" -f $Adapters[$i].MacAddress)
        # Write the status of the adapter in red
        Write-Host ("|{0,-8}" -f $Adapters[$i].Status) -NoNewline -ForegroundColor Red
        # Write the link speed of the adapter in magenta
        Write-Host ("|{0,-$LinkLength}" -f $Adapters[$i].LinkSpeed) -ForegroundColor Magenta
    }

    # Get the max count of available network adapters and add 1 to it, assign the number as exit value to break the loop when selected
    $ExitCodeAdapterSelection = $Adapters.Count + 1

    # Write an exit option at the end of the table
    Write-Host ("{0,-5}" -f "$ExitCodeAdapterSelection") -NoNewline -ForegroundColor DarkRed
    Write-Host "|Cancel" -ForegroundColor DarkRed

    # Define a function to validate the user input
    function Confirm-Choice {
        param($Choice)
        # Get an array of valid numbers from 1 to $ExitCodeAdapterSelection
        $ValidNumbers = 1..$ExitCodeAdapterSelection
        # Initialize a flag to indicate if the input is valid or not
        $IsValid = $false
        # Loop through each valid number and compare it with the input
        foreach ($Number in $ValidNumbers) {
            # If the input is equal to a valid number, set the flag to true and break the loop
            if ($Choice -eq $Number) {
                $IsValid = $true
                break
            }
        }
        # Return the flag value
        return $IsValid
    }

    # Prompt the user to enter the number of the adapter they want to select, or exit value to exit, until they enter a valid input
    do {
        $Choice = Read-Host "Enter the number of the adapter you want to select or press $ExitCodeAdapterSelection to Cancel`n"
        # Check if the input is valid using the Confirm-Choice function
        if (-not (Confirm-Choice $Choice)) {
            # Write an error message in red if invalid
            Write-Host "Invalid input. Please enter a number between 1 and $ExitCodeAdapterSelection." -ForegroundColor Red
        }
    } while (-not (Confirm-Choice $Choice))

    # Check if the user entered the exit value to break out of the loop
    if ($Choice -eq $ExitCodeAdapterSelection) {
        # Write a message in white and break out of the loop
        Write-Host "Exiting..." -ForegroundColor Magenta
        # Send False flag to the caller function to indicate that the user cancelled the operation        
        return $false
        break
    }
    else {
        # Get the selected adapter from the array and display it
        $ActiveNetworkInterface = $Adapters[$Choice - 1]
        return $ActiveNetworkInterface
    }            
}
