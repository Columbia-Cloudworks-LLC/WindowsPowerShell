# Define constants
$CabUrl = 'https://catalog.s.download.windowsupdate.com/microsoftupdate/v6/wsusscan/wsusscn2.cab'
$CabFile = Join-Path -Path $PSScriptRoot -ChildPath 'wsusscn2.cab'
$UpdateThresholdDays = 30

# Check if the CAB file exists and is fresh enough
$DownloadCab = $true
if (Test-Path -Path $CabFile) {
    $LastModified = (Get-Item $CabFile).LastWriteTime
    if ((Get-Date) - $LastModified -lt (New-TimeSpan -Days $UpdateThresholdDays)) {
        Write-Output "CAB file exists and is recent (modified: $LastModified). No download needed."
        $DownloadCab = $false
    }
    else {
        Write-Output "CAB file exists but is outdated (modified: $LastModified). Downloading new version."
    }
}
else {
    Write-Output "CAB file does not exist. Downloading..."
}

# Download the CAB file if necessary
if ($DownloadCab) {
    try {
        Invoke-WebRequest -Uri $CabUrl -OutFile $CabFile -UseBasicParsing
        Write-Output "Download completed successfully."
    }
    catch {
        Write-Error "Failed to download CAB file: $_"
    }
}

