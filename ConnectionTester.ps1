param(
    [string[]]$ComputerName,              # List of computers passed as parameter (optional)
    [string]$InputListFile = "servers.txt", # Path to text file with computer names (used if $ComputerName not provided)
    [string]$OutputCsv                    # Optional output CSV file path for results
)

# If no computers passed via parameter, read from the servers.txt file
if (-not $ComputerName) {
    if (Test-Path -Path $InputListFile) {
        $ComputerName = Get-Content -Path $InputListFile
    } else {
        Write-Error "No computer list provided and '$InputListFile' not found. Exiting."
        return
    }
}

# Ensure we have at least one computer to process
if (!$ComputerName -or $ComputerName.Count -eq 0) {
    Write-Error "No computer names to test. Exiting."
    return
}

# Prepare a list to hold results
$results = @()

# Set up progress tracking
$totalComputers = $ComputerName.Count
$totalTestsPerComputer = 4  # Ping, RDP, WinRM, AdminShare
$totalSteps = $totalComputers * $totalTestsPerComputer
$completedSteps = 0

# Timestamp for log file (if needed)
$timestamp = (Get-Date -Format "yyyyMMdd_HHmmss")

# Determine log file path if output CSV is specified
$logFile = $null
if ($OutputCsv) {
    $outDir = Split-Path -Path $OutputCsv -Parent
    if (-not $outDir) { $outDir = "." }  # if only file name given, use current directory
    $logFile = Join-Path -Path $outDir -ChildPath "ConnectivityFailures_${timestamp}.log"
}

foreach ($server in $ComputerName) {
    # Initialize status variables
    $pingStatus   = "Success"
    $rdpStatus    = "Success"
    $winRMStatus  = "Success"
    $shareStatus  = "Success"

    # 1. Ping test
    Write-Progress -Activity "Testing connectivity" -Status "[$server] Ping test..." -PercentComplete (($completedSteps / $totalSteps) * 100)
    $pingResult = $false
    try {
        # Send one ping, short timeout (1 second), stop on error (e.g., DNS failure)
        $pingResult = Test-Connection -ComputerName $server -Count 1 -Quiet -TimeoutSeconds 1 -ErrorAction Stop
    } catch {
        $pingResult = $false
    }
    if (-not $pingResult) {
        $pingStatus = "Fail"
    }
    $completedSteps++

    # 2. RDP port test (TCP 3389)
    Write-Progress -Activity "Testing connectivity" -Status "[$server] RDP port 3389 test..." -PercentComplete (($completedSteps / $totalSteps) * 100)
    $rdpOpen = $false
    try {
        # Test-NetConnection returns True/False with -InformationLevel Quiet (or use -Quiet in newer PS versions)
        $rdpOpen = Test-NetConnection -ComputerName $server -Port 3389 -InformationLevel Quiet -ErrorAction Stop
    } catch {
        $rdpOpen = $false
    }
    if (-not $rdpOpen) {
        $rdpStatus = "Fail"
    }
    $completedSteps++

    # 3. WinRM (WS-Man) test
    Write-Progress -Activity "Testing connectivity" -Status "[$server] WinRM (WS-Man) test..." -PercentComplete (($completedSteps / $totalSteps) * 100)
    $winRMOK = $false
    try {
        # Test-WSMan will throw if WinRM is not reachable; no need to capture output on success
        Test-WSMan -ComputerName $server -ErrorAction Stop | Out-Null
        $winRMOK = $true
    } catch {
        $winRMOK = $false
    }
    if (-not $winRMOK) {
        $winRMStatus = "Fail"
    }
    $completedSteps++

    # 4. Admin Share (C$) access test
    Write-Progress -Activity "Testing connectivity" -Status "[$server] Admin share (C$) access test..." -PercentComplete (($completedSteps / $totalSteps) * 100)
    $shareOK = $false
    try {
        # Try accessing the C$ share. If accessible, Test-Path returns True.
        if (Test-Path "\\$server\C$" -ErrorAction Stop) {
            $shareOK = $true
        } else {
            $shareOK = $false
        }
    } catch {
        $shareOK = $false
    }
    if (-not $shareOK) {
        $shareStatus = "Fail"
    }
    $completedSteps++

    # Create an object with the results for this server
    $resultObject = [PSCustomObject]@{
        Computer    = $server
        Ping        = $pingStatus
        RDP         = $rdpStatus
        WinRM       = $winRMStatus
        AdminShare  = $shareStatus
    }
    $results += $resultObject

    # Log to file if any test failed for this server
    if ($logFile -and ($pingStatus -eq "Fail" -or $rdpStatus -eq "Fail" -or $winRMStatus -eq "Fail" -or $shareStatus -eq "Fail")) {
        # Build a failure summary for this server
        $failedTests = @()
        if ($pingStatus  -eq "Fail") { $failedTests += "Ping" }
        if ($rdpStatus   -eq "Fail") { $failedTests += "RDP" }
        if ($winRMStatus -eq "Fail") { $failedTests += "WinRM" }
        if ($shareStatus -eq "Fail") { $failedTests += "AdminShare" }
        $failLine = "$server - $($failedTests -join ', ') failed."
        Add-Content -Path $logFile -Value $failLine
    }
}

# Close out the progress bar
Write-Progress -Activity "Testing connectivity" -Completed -Status "All tests completed."

# Output results to console as a table
$results | Format-Table -AutoSize

# Export to CSV if requested
if ($OutputCsv) {
    try {
        $results | Export-Csv -Path $OutputCsv -NoTypeInformation -Force
        Write-Host "Results exported to $OutputCsv"
        if ($logFile) {
            Write-Host "Failure log saved to $logFile"
        }
    } catch {
        Write-Error "Failed to write CSV output: $($_.Exception.Message)"
    }
}
