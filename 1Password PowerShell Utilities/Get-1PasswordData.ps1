<#
.SYNOPSIS
    Retrieves and displays all properties of 1Password items using the 1Password CLI.

.DESCRIPTION
    This script reads a list of item IDs from a file and uses the 1Password CLI to fetch and display
    the full details of each item. The output includes all properties of the item, which can be inspected
    to determine available fields and members for further processing.

    WARNING: The output may contain sensitive information such as passwords. Ensure that the console output
    is handled securely (e.g., avoid logging or redirect to a secure file).

.PARAMETER filePath
    The path to the file containing the list of 1Password item IDs (one per line).

.EXAMPLE
    .\Get-1PasswordItemProperties.ps1 -filePath "C:\path\to\ids.txt"
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$filePath
)

# Ensure the 1Password CLI is installed and authenticated
# Run 'op signin' if you are not already signed in to the 1Password CLI

# Read the file containing the list of item IDs
$ids = Get-Content $filePath

foreach ($id in $ids) {
    try {
        # Get item details using op item get --json
        $itemJson = & op item get --json $id 2>&1
        $item = $itemJson | ConvertFrom-Json

        # Output separator and item details
        Write-Host "----- Item ID: $id -----"
        $item | Format-List
        Write-Host "-------------------------"
    } catch {
        Write-Error "Error retrieving data for ID: $id. Details: $_"
    }
}