# User-Defined Variables
$ExternalTargetIP = "8.8.8.8"  # IP address of a reliable pingable target such as Google DNS
$RunTimeMin = 90  # Number of minutes the connectivity scanner should run.
$Interval = 5  # Interval in seconds between checks



# Script Variables
$StartTime = Get-Date
$EndTime = $StartTime.AddMinutes($RunTimeMin)
$TotalDuration = $EndTime - $StartTime
$LogFile = [IO.Path]::Combine($env:TEMP, ".InternetConnectionLog")
$ArchiveLogFolder = [Environment]::GetFolderPath('Desktop')
$ArchiveLogFile = Join-Path $ArchiveLogFolder "InternetConnectionLog.csv"
$PreviousStatus = 'Unknown'
$LastStatusChangeTime = $StartTime



# Script Functions
# Displays the archive log file in a seperate conosle window without stopping the flow of calling process
# This function creates, runs, and deletes the script for idempotency.
function DisplayArchiveLog {
	# Define the script content
	$ScriptContent = @"
param(
    [string]`$File
)
do {
    try {
        Clear-Host
        `$data = Import-Csv -Path `$File
        `$data | Format-Table -AutoSize
        Start-Sleep -Seconds 5
    } catch {
        Write-Host "Error: `$($_.Exception.Message)"
    }
} while (`$true)
"@

	# Path to the temporary script file
	$TempScriptFile = [IO.Path]::Combine($env:TEMP, "DisplayLog.ps1")

	# Write the script content to the temporary file
	Set-Content -Path $TempScriptFile -Value $ScriptContent -Encoding UTF8

	# Start the new PowerShell process with ExecutionPolicy Bypass
	Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass", "-NoExit", "-File", "`"$TempScriptFile`"", "`"$ArchiveLogFile`""

	# Clean up temporary script file after a delay to ensure the new process has started
	Start-Sleep -Seconds 2
	Remove-Item -Path $TempScriptFile -Force
}



########################
# MAIN Script Function #
########################
Write-Host "Initializing Scanner..."

# Check if the log file exists
if (Test-Path $LogFile) {
    # Read the contents of the log file, skipping the first line (header)
    if (-Not (Test-Path $ArchiveLogFile)) {
        $LogContents = Get-Content $LogFile
    } else {
        $LogContents = Get-Content $LogFile | Select-Object -Skip 1
    }

    # Append the contents to the archive log file if there's any data to append
    if ($LogContents) {
        # Ensure the archive log file exists before appending, or create a blank one
        if (-not (Test-Path $ArchiveLogFile)) {
            Out-File -FilePath $ArchiveLogFile
        }

        # Append the contents to the archive log file
        $LogContents | Out-File -FilePath $ArchiveLogFile -Append
    }

    # Remove the original log file
    Remove-Item $LogFile -Force
}

# Initialize the CSV file with headers if it doesn't exist
if (-Not (Test-Path $LogFile)) {
    Write-Output "`"Timestamp`",`"Status,`"Latency(ms)`",Details`"" | Out-File -FilePath $LogFile -Encoding utf8
}

# Run the DisplayArchiveLog script function to show the history of outages.
DisplayArchiveLog

while ((Get-Date) -lt $EndTime) {

    $CurrentTime = Get-Date
    $TimeRemaining = $EndTime - $CurrentTime

    # Calculate percentage completed
    $TimeElapsed = $CurrentTime - $StartTime
    $PercentageCompleted = ($TimeElapsed.TotalSeconds / $TotalDuration.TotalSeconds) * 100
    $PercentageCompleted = [math]::Min(100, [math]::Max(0, [math]::Round($PercentageCompleted)))

    # Create ASCII progress bar
    $ProgressBarLength = 20  # Total length of the progress bar
    $FilledLength = [math]::Round(($PercentageCompleted / 100) * $ProgressBarLength)
    $ProgressBar = "[" + ('|' * $FilledLength).PadRight($ProgressBarLength) + "] $PercentageCompleted%"

    # Check internet connection by pinging a reliable server
    $PingResult = Test-Connection -ComputerName $ExternalTargetIP -Count 1 -ErrorAction SilentlyContinue

    if ($PingResult) {
        $Status = "Up"
        $Latency = (Test-Connection -ComputerName $ExternalTargetIP -Count 1).Latency
        $Details = "Ping successful"
    } else {
        $Status = "Down"
        $Latency = "*"
        $Details = "Ping failed"
    }

    # If the status has changed, log it and update the last status change time
    if ($Status -ne $PreviousStatus) {
        # Record the change in the log file with values encapsulated in double quotes
        $LogEntry = "`"$($CurrentTime)`",`"$Status`",`"$Latency`",`"$Details`""
        $LogEntry | Out-File -FilePath $LogFile -Append -Encoding utf8

        $LastStatusChangeTime = $CurrentTime
    }

    $PreviousStatus = $Status

    # Read logged outages from the log file
    # Sleep for 2 seconds to prevent file lock conflicts between write and read of the $logFile
    Start-Sleep -Seconds 2
    $LoggedOutages = Import-Csv -Path $LogFile | Where-Object { $_.Status -eq 'Down' }

    # Clear the host screen
    Clear-Host

    # Display current status and times
    Write-Host "Pinging $ExternalTargetIP for $RunTimeMin minutes..."
    Write-Host "==== Current Status ====" -ForegroundColor Cyan
    Write-Host "Current Status      : " -NoNewLine -ForegroundColor Magenta
    if ($Status -eq "Up") { Write-Host "$Status" -ForegroundColor Green }
    if ($Status -eq "Down") { Write-Host "$Status" -ForegroundColor Red}
	Write-Host "Latency             : $Latency"
    Write-Host "Start Time          : $StartTime"
    Write-Host "Last Status Change  : $LastStatusChangeTime"
    Write-Host "Current Time        : $CurrentTime"
    Write-Host "End Time            : $EndTime ($($RunTimeMin) minutes)"
    Write-Host "Time Remaining      : $($TimeRemaining.ToString("hh\:mm\:ss"))"
    Write-Host "Progress            : $ProgressBar"
	
    Write-Host "`nPress CTRL+C to stop scanning..."

    # Display logged outages
    Write-Host "`n==== Logged Outages ====" -ForegroundColor Cyan
    if ($LoggedOutages) {
        foreach ($Outage in $LoggedOutages) {
            Write-Host "[$($Outage.Timestamp)] Status: $($Outage.Status), Details: $($Outage.Details)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "No outages recorded." -ForegroundColor Green
    }

    # Wait for the specified interval before checking again
    Start-Sleep -Seconds $Interval
}

# Final message
Write-Host "`nMonitoring complete. Check the log file at $LogFile for details." -ForegroundColor Green
