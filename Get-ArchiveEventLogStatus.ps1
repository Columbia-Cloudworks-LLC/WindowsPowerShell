function Get-ArchiveEventLogStatus {
    <#
    .SYNOPSIS
    Returns the age (in days) of the oldest archive‐ZIP under D:\ibmeventlogs on a remote server,
    using the SMB administrative share (\\Server\D$).

    .PARAMETER ServerName
    The NetBIOS/hostname (or FQDN) of the remote server.

    .OUTPUTS
    PSCustomObject with properties:
      - Server         : Name of the server checked.
      - OldestZipDate  : [DateTime] LastWriteTime of the oldest ZIP file found.
      - AgeDays        : [Double] “Age” in days between now and OldestZipDate (rounded to two decimals).

    .NOTES
    - No WinRM/PSRemoting is required; it enumerates files via \\Server\D$\ibmeventlogs.
    - If the D:\ibmeventlogs folder (or D$ share) is inaccessible, you’ll get an error.
    - If there are no ZIPs under D:\ibmeventlogs, the function returns $null.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $ServerName
    )

    # Compose the UNC path to the archive‐log folder:
    $uncRoot = "\\$ServerName\D$\ibmeventlogs"

    try {
        # First, verify that the path exists and is accessible:
        if (-not (Test-Path -LiteralPath $uncRoot -PathType Container)) {
            Write-Error "Cannot access '$uncRoot'. Ensure the D$ share is reachable and you have permissions."
            return
        }

        # Get all .zip files under that path (recursively).
        $zipFiles = Get-ChildItem -LiteralPath $uncRoot `
                                  -Filter '*.zip' `
                                  -Recurse `
                                  -File `
                                  -ErrorAction SilentlyContinue

        if (-not $zipFiles -or $zipFiles.Count -eq 0) {
            # No ZIP files found ⇒ return $null (you can modify this behavior if desired).
            return $null
        }

        # Find the oldest LastWriteTime among all ZIPs:
        $oldestZip = $zipFiles |
            Sort-Object -Property LastWriteTime |
            Select-Object -First 1

        $oldestDate = $oldestZip.LastWriteTime

        # Compute “age” in days (total, to 2 decimal places):
        $timespan = (Get-Date) - $oldestDate
        $ageDays  = [math]::Round($timespan.TotalDays, 2)

        # Return a PSCustomObject with Server, date, and age:
        [PSCustomObject]@{
            Server        = $ServerName
            OldestZipDate = $oldestDate
            AgeDays       = $ageDays
        }
    }
    catch {
        Write-Error "Error while scanning '\\$ServerName\D$\ibmeventlogs': $_"
    }
}

# Check “DC01”:
$status = Get-ArchiveEventLogStatus -ServerName 'DC01'

if ($status) {
    "Server:        $($status.Server)"
    "OldestZipDate: $($status.OldestZipDate)"
    "Age (days):    $($status.AgeDays)"
} else {
    "No ZIPs found under D:\ibmeventlogs (or folder inaccessible)."
}
