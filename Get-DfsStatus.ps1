function Get-DfsStatus {
    <#
    .SYNOPSIS
    Checks DFSR/DFS Namespace service health and recent errors on a given server.

    .DESCRIPTION
    This function will:
      1. Query the status of the DFS Replication service (DFSR) on the remote server.
      2. Query the status of the DFS Namespace service (DFS), if present.
      3. Pull back any errors or warnings from the DFS Replication event log in the last X hours.
      4. Optionally (if you supply a partner), get the SYSVOL replication backlog between this server and the partner.

    .PARAMETER ServerName
      The NetBIOS or FQDN of the machine (e.g. a DC) you want to check.

    .PARAMETER LookbackHours
      How many hours back to scan for DFSR errors (default: 24).

    .PARAMETER SysvolPartner
      (Optional) The name of another DC to compare SYSVOL DFSR backlog against. If you leave this out,
      the backlog check is skipped.

    .OUTPUTS
      A PSCustomObject with fields:
        • ServerName
        • DfsrServiceStatus
        • DfsServiceStatus
        • RecentDfsrErrors
        • RecentDfsrWarnings
        • SysvolBacklog (if partner provided)

    .EXAMPLE
      Get-DfsStatus -ServerName DC1 -LookbackHours 12

    .EXAMPLE
      # Check DC1 against DC2 for SYSVOL backlog, scanning last 6 hours of logs
      Get-DfsStatus -ServerName DC1 -SysvolPartner DC2 -LookbackHours 6
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string] $ServerName,

        [Parameter(Mandatory=$false)]
        [int] $LookbackHours = 24,

        [Parameter(Mandatory=$false)]
        [string] $SysvolPartner
    )

    # 1) Check the DFSR service on the remote server
    try {
        $dfsrSvc = Get-Service -ComputerName $ServerName -Name 'DFSR' -ErrorAction Stop
        $dfsrStatus = $dfsrSvc.Status
    }
    catch {
        $dfsrStatus = "ERROR: Unable to query DFSR service (`DFSR`) on $ServerName"
    }

    # 2) Check the DFS Namespace service (if installed)
    try {
        $dfsSvc = Get-Service -ComputerName $ServerName -Name 'DFS' -ErrorAction Stop
        $dfsStatus = $dfsSvc.Status
    }
    catch {
        # If DFS Namespace service isn’t present, note that—but it’s not necessarily an error
        $dfsStatus = "Not Installed / Not Found"
    }

    # 3) Pull recent DFSR errors & warnings from the event log
    #    Source for DFSR events is “DFS Replication”
    $cutoff = (Get-Date).AddHours(-1 * $LookbackHours)
    $hashTbl = @{
        LogName   = 'DFS Replication'
        StartTime = $cutoff
        Level     = 2..3   # 2 = Error, 3 = Warning
    }
    try {
        $events = Get-WinEvent -ComputerName $ServerName -FilterHashtable $hashTbl -ErrorAction Stop
        $dfsErrors   = $events | Where-Object { $_.LevelDisplayName -eq 'Error' }   |
                       Select-Object -Property TimeCreated, Id, Message
        $dfsWarnings = $events | Where-Object { $_.LevelDisplayName -eq 'Warning' } |
                       Select-Object -Property TimeCreated, Id, Message
    }
    catch {
        $dfsErrors   = @("ERROR: Unable to query DFS Replication event log on $ServerName")
        $dfsWarnings = @()
    }

    # 4) (Optional) If SysvolPartner is supplied, check SYSVOL backlog
    $backlogInfo = $null
    if ($SysvolPartner) {
        # We assume the DFS Replication group for SYSVOL is named "Domain System Volume".
        # If your environment uses a different replication group name, change accordingly.
        $rgName    = 'Domain System Volume'
        $folderName = 'SYSVOL Share'

        try {
            # Need the DFSR PowerShell module. If not present, this part will throw.
            Import-Module Dfsr -ErrorAction Stop

            # We’ll attempt to get backlog count between the two servers
            $backlogCount = Get-DfsrBacklog `
                -GroupName $rgName `
                -FolderName $folderName `
                -SourceComputerName $ServerName `
                -DestinationComputerName $SysvolPartner

            $backlogInfo = @{
                Source      = $ServerName
                Destination = $SysvolPartner
                Backlog     = $backlogCount
            }
        }
        catch {
            $backlogInfo = @{
                Source      = $ServerName
                Destination = $SysvolPartner
                Backlog     = "ERROR: Could not calculate backlog (module missing or invalid group/folder)."
            }
        }
    }

    # Build output object
    $output = [PSCustomObject]@{
        ServerName           = $ServerName
        DfsrServiceStatus    = $dfsrStatus
        DfsServiceStatus     = $dfsStatus
        RecentDfsrErrors     = if ($dfsErrors)   { $dfsErrors   } else { @() }
        RecentDfsrWarnings   = if ($dfsWarnings) { $dfsWarnings } else { @() }
        SysvolBacklog        = $backlogInfo
    }

    return $output
}
