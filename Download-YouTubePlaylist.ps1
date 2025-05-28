# Define variables
$PlaylistURL = "https://www.youtube.com/playlist?list=PL1B-j88Vc1RFqS2L2zit3DLiPcJqLKnac"
$OutputDirectory = "C:\Users\viral\OneDrive\Videos\YouTube\Best-of-Cum-Town-Bits"

$DownloadArchive = "C:\Users\viral\OneDrive\Videos\YouTube\downloaded.txt"
$LogFile = "C:\Users\viral\OneDrive\Videos\YouTube\download.log"

# Specify paths to executables
$ytDlpPath = "C:\Windows\yt-dlp.exe"
$ffmpegPath = "C:\Windows\ffmpeg.exe"

# Create the output argument with explicit quotes to handle spaces in the path
$outputPattern = "`"$OutputDirectory\%(title)s.%(ext)s`""

# Build arguments for yt-dlp
$arguments = @(
    "--cookies-from-browser","firefox",
    "--download-archive", $DownloadArchive,
    "--ffmpeg-location", $ffmpegPath,
    "-o", $outputPattern,
    "-f", "bestvideo+bestaudio",
    "--merge-output-format", "mp4",
    $PlaylistURL
)

Write-Output "Starting download process..."

# Execute yt-dlp and use Tee-Object to both display output and log it to a file
& $ytDlpPath @arguments 2>&1 | Tee-Object -FilePath $LogFile -Encoding utf8

Write-Output "Download process completed. Log written to $LogFile."
