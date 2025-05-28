# Check if ImportExcel module is installed, install if not
if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Install-Module -Name ImportExcel -Scope CurrentUser -Force
}

# Import the module
Import-Module ImportExcel

# Read API credentials from x.api.json
$credentialsPath = "x.api.json"
if (-not (Test-Path $credentialsPath)) {
    Write-Error "API credentials file 'x.api.json' not found."
    exit
}

$jsonData = Get-Content $credentialsPath | ConvertFrom-Json
$BearerToken = $jsonData.BearerToken

# Set up headers for API requests
$headers = @{
    "Authorization" = "Bearer $BearerToken"
    "Content-Type"  = "application/json"
}

# Prompt for the Twitter username
$username = Read-Host "Enter the Twitter username (without @):"

# Base URL for Twitter API
$baseUrl = "https://api.twitter.com/2"

# Step 1: Get the user ID from the username
$userUrl = "$baseUrl/users/by/username/$username"

Write-Progress -Activity "Fetching User ID" -Status "Getting user ID for $username"

try {
    $userResponse = Invoke-RestMethod -Method Get -Uri $userUrl -Headers $headers
} catch {
    Write-Error "Failed to fetch user ID: $_"
    exit
}

if (-not $userResponse.data) {
    Write-Error "User not found."
    exit
}

$userId = $userResponse.data.id

# Step 2: Fetch tweets from the user
$tweetsUrl = "$baseUrl/users/$userId/tweets"

# Calculate start_time (24 hours ago in ISO8601 format)
$startTime = (Get-Date).AddHours(-24).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

# Initialize variables
$tweets = @()
$users = @{}
$nextToken = $null
$count = 0

do {
    # Build query parameters
    $queryParams = @{
        "max_results"  = "100"
        "start_time"   = $startTime
        "tweet.fields" = "created_at,public_metrics,author_id"
        "expansions"   = "author_id"
        "user.fields"  = "name,username"
    }

    if ($nextToken) {
        $queryParams["pagination_token"] = $nextToken
    }

    # Build request URL
    $queryString = ($queryParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$([uri]::EscapeDataString($_.Value))" }) -join "&"
    $requestUrl = "$tweetsUrl?$queryString"

    # Show progress
    Write-Progress -Activity "Fetching tweets" -Status "Processing page $($count + 1)"

    try {
        # Make the API request
        $response = Invoke-RestMethod -Method Get -Uri $requestUrl -Headers $headers
    } catch {
        Write-Error "Failed to fetch tweets: $_"
        exit
    }

    # Process tweets
    if ($response.data) {
        $tweets += $response.data
    }

    # Process users
    if ($response.includes.users) {
        foreach ($user in $response.includes.users) {
            $users[$user.id] = $user
        }
    }

    # Check for next_token
    if ($response.meta.next_token) {
        $nextToken = $response.meta.next_token
    } else {
        $nextToken = $null
    }

    $count += 1

} while ($nextToken)

# Prepare data for Excel
$outputData = @()
foreach ($tweet in $tweets) {
    $authorId = $tweet.author_id
    $user = $users[$authorId]

    $posted = $tweet.created_at
    $username = $user.username
    $displayName = $user.name
    $tweetText = $tweet.text
    $tweetId = $tweet.id
    $permalink = "https://twitter.com/$username/status/$tweetId"
    $likes = $tweet.public_metrics.like_count
    $comments = $tweet.public_metrics.reply_count
    $retweets = $tweet.public_metrics.retweet_count
    $quoteTweets = $tweet.public_metrics.quote_count
    $views = $tweet.public_metrics.impression_count
    if (-not $views) {
        $views = 0
    }

    # Calculate Ratio (comments to likes ratio)
    if ($likes -ne 0) {
        $ratio = [math]::Round($comments / $likes, 2)
    } else {
        $ratio = 0
    }

    $outputData += [pscustomobject]@{
        Posted         = $posted
        Username       = $username
        "Display Name" = $displayName
        Tweet          = $tweetText
        Permalink      = $permalink
        Likes          = $likes
        Comments       = $comments
        Views          = $views
        Retweets       = $retweets
        Ratio          = $ratio
    }
}

# Write data to Excel
$filePath = "tweets.xlsx"
$worksheetName = "tweets"

if (Test-Path $filePath) {
    # Read existing data and append new data
    $existingData = Import-Excel -Path $filePath -WorksheetName $worksheetName
    $combinedData = $existingData + $outputData
    $combinedData | Export-Excel -Path $filePath -WorksheetName $worksheetName -AutoSize -Force
} else {
    # Create new Excel file with data
    $outputData | Export-Excel -Path $filePath -WorksheetName $worksheetName -AutoSize
}

Write-Host "Tweets have been successfully written to '$filePath'."
