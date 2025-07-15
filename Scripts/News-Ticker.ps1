# Function to update a specific line on the console.
function Write-AtPosition {
    param(
        [int]$X,
        [int]$Y,
        [string]$Text
    )
    $rawUI = $Host.UI.RawUI
    $cursorPos = $rawUI.CursorPosition
    $cursorPos.X = $X
    $cursorPos.Y = $Y
    $rawUI.CursorPosition = $cursorPos

    # Clear the entire line first.
    $lineLength = $rawUI.WindowSize.Width
    $padding = " " * $lineLength
    Write-Host $padding -NoNewline

    # Reposition and write the new text.
    $cursorPos.X = $X
    $rawUI.CursorPosition = $cursorPos
    Write-Host $Text -NoNewline
}

# Function to output clickable hyperlinks using OSC 8.
function Write-Hyperlink {
    param(
        [string]$Url,
        [string]$Text
    )
    $esc = [char]27
    # Build the OSC 8 hyperlink sequence.
    $hyperlink = "$esc]8;;$Url$esc\$Text$esc]8;;$esc\"
    Write-Host $hyperlink -NoNewline
}

# Main loop: refresh every 5 minutes (300 seconds).
while ($true) {
    # Clear the console before redrawing.
    Clear-Host

    # Load API key from JSON file.
    try {
        $apiKeyObj = Get-Content ".\news.api.key.json" | ConvertFrom-Json
        $apiKey = $apiKeyObj.apiKey
    }
    catch {
        Write-Host "Failed to load API key from .\news.api.key.json. Check the file!" -ForegroundColor Red
        break
    }

    # Display header.
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host "            US News Ticker             " -ForegroundColor Cyan
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host ""

    # Build the API URL for US headlines.
    $url = "https://newsapi.org/v2/top-headlines?country=us&apiKey=$apiKey"

    # Retrieve headlines.
    try {
        $news = Invoke-RestMethod -Uri $url -Method Get
    }
    catch {
        Write-Host "Error fetching news: $_" -ForegroundColor Red
        Write-Host "Retrying in 30 seconds..."
        Start-Sleep -Seconds 30
        continue
    }

    # Display headlines with clickable hyperlinks if supported.
    Write-Host "Top Headlines:" -ForegroundColor Yellow
    Write-Host "--------------"
    $index = 1
    foreach ($article in $news.articles) {
        Write-Host "$index. " -NoNewline
        # Output the headline as a clickable hyperlink.
        Write-Hyperlink $article.url $article.title
        Write-Host ""
        $index++
    }
    Write-Host ""

    # Reserve a line for the countdown.
    $countdownY = $Host.UI.RawUI.CursorPosition.Y
    Write-Host "Next update in: 300 seconds"
    Write-Host "Press CTRL+C to Exit" -ForegroundColor Green

    # Countdown loop: update the countdown line every second.
    $totalSeconds = 300
    for ($i = $totalSeconds; $i -ge 0; $i--) {
        Write-AtPosition -X 0 -Y $countdownY -Text "Next update in: $i seconds"
        Start-Sleep -Seconds 1
    }
}
