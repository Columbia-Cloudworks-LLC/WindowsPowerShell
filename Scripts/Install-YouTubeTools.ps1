# yt-dlp
# https://github.com/yt-dlp/yt-dlp

# ffmpeg
# https://www.ffmpeg.org/download.html

# Function to check if the script is running as administrator
function Ensure-ElevatedPrivileges {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "This script requires administrative privileges. Please run it as an administrator."
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -Verb RunAs
        exit
    }
}

# Check for administrative privileges
Ensure-ElevatedPrivileges

# Check PowerShell version
if ($PSVersionTable.PSVersion -lt [Version]::new(5, 2)) {
    Write-Error "This script requires PowerShell 5.2 or higher. Please update your PowerShell version."
    exit
}

# Define URLs and paths
$ytDlpUrl = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe"
$ffmpegReleaseUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-full.7z"
$windowsDir = [System.Environment]::GetFolderPath("Windows")

$ytDlpPath = Join-Path -Path $windowsDir -ChildPath "yt-dlp.exe"
$ffmpegArchivePath = Join-Path -Path $windowsDir -ChildPath "ffmpeg-release-full.7z"
$ffmpegExtractPath = Join-Path -Path $windowsDir -ChildPath "ffmpeg"

# Function to download a file using Invoke-RestMethod
function Download-File {
    param (
        [string]$Url,
        [string]$OutputPath
    )
    Write-Host "Downloading $Url to $OutputPath..."
    try {
        Invoke-RestMethod -Uri $Url -OutFile $OutputPath -ErrorAction Stop
        Write-Host "Download completed: $OutputPath"
    } catch {
        Write-Error "Failed to download $Url. Error: $_"
    }
}

# Function to extract FFmpeg archive
function Extract-FFmpeg {
    param (
        [string]$ArchivePath,
        [string]$OutputDir
    )
    Write-Host "Extracting FFmpeg from $ArchivePath to $OutputDir..."
    # Check if Expand-Archive is available (Windows PowerShell 5+)
    if (-Not (Get-Command "Expand-Archive" -ErrorAction SilentlyContinue)) {
        Write-Error "Expand-Archive cmdlet is not available. Ensure you're using a compatible version of PowerShell."
        return
    }

    # Create the output directory if it doesn't exist
    if (-Not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    # Extract using Expand-Archive
    Expand-Archive -Path $ArchivePath -DestinationPath $OutputDir -Force
    Write-Host "FFmpeg extraction complete."
}

# Download yt-dlp
Download-File -Url $ytDlpUrl -OutputPath $ytDlpPath

# Download FFmpeg archive
Download-File -Url $ffmpegReleaseUrl -OutputPath $ffmpegArchivePath

# Extract FFmpeg
Extract-FFmpeg -ArchivePath $ffmpegArchivePath -OutputDir $ffmpegExtractPath

# Clean up the archive
Write-Host "Cleaning up FFmpeg archive..."
Remove-Item -Path $ffmpegArchivePath -Force -ErrorAction SilentlyContinue

Write-Host "FFmpeg and yt-dlp setup completed successfully in $windowsDir."
