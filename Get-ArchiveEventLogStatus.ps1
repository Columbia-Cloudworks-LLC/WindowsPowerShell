function Get-ArchiveEventLogStatus {
    <#
    .SYNOPSIS
    Retrieves the age (in days) of the oldest archived event log (inside any ZIP) under D:\ibmeventlogs on a given server.

    .PARAMETER ServerName
    The name (or IP) of the remote server to check.

    .OUTPUTS
    PSCustomObject with properties:
      - Server        : The remote machine’s name.
      - OldestLogDate : [DateTime] of the oldest entry inside any ZIP under D:\ibmeventlogs.
      - AgeDays       : [Double] Number of days between now and the OldestLogDate (rounded to 2 decimals).

    .NOTES
    - Requires the target machine to be reachable via PowerShell remoting (WinRM).
    - Assumes every ZIP in D:\ibmeventlogs is accessible and not locked by another process.
    - If no ZIPs or no entries are found, returns $null.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $ServerName
    )

    try {
        Invoke-Command -ComputerName $ServerName -ErrorAction Stop -ScriptBlock {
            # Ensure the ZIP‐filesystem assembly is loaded
            Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop

            $rootPath = 'D:\ibmeventlogs'
            # Get all ZIP files under D:\ibmeventlogs (recursively)
            $zipFiles = Get-ChildItem -Path $rootPath -Filter '*.zip' -Recurse -File -ErrorAction SilentlyContinue

            if (-not $zipFiles -or $zipFiles.Count -eq 0) {
                # No ZIP files found
                return $null
            }

            # Collect all entry timestamps
            $entryDates = [System.Collections.Generic.List[DateTime]]::new()

            foreach ($zipFile in $zipFiles) {
                try {
                    $zipArchive = [System.IO.Compression.ZipFile]::OpenRead($zipFile.FullName)
                    foreach ($entry in $zipArchive.Entries) {
                        # Skip directory entries (their FullName ends with '/')
                        if (-not $entry.FullName.EndsWith('/')) {
                            $entryDates.Add($entry.LastWriteTime.DateTime)
                        }
                    }
                    $zipArchive.Dispose()
                } catch {
                    # If one ZIP fails to open, skip it
                    Write-Verbose "Failed to open ZIP: $($zipFile.FullName). Skipping. $_"
                }
            }

            if ($entryDates.Count -eq 0) {
                # No files inside any ZIP
                return $null
            }

            # Find the oldest (minimum) timestamp
            $oldestDate = $entryDates | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum

            # Calculate age in days (double, rounded to 2 decimals)
            $timeSpan = (Get-Date) - $oldestDate
            $ageDays  = [math]::Round($timeSpan.TotalDays, 2)

            # Return a PSCustomObject
            return [PSCustomObject]@{
                Server        = $env:COMPUTERNAME
                OldestLogDate = $oldestDate
                AgeDays       = $ageDays
            }
        }
    }
    catch {
        Write-Error "Unable to contact server '$ServerName' or an error occurred: $_"
    }
}

# Retrieve the archive‐event‐log status for "DC01"
$report = Get-ArchiveEventLogStatus -ServerName 'DC01'
if ($report) {
    "Server:        $($report.Server)"
    "OldestLogDate: $($report.OldestLogDate)"
    "Age (days):    $($report.AgeDays)"
} else {
    "No archive logs found under D:\ibmeventlogs (or unable to read)."
}
