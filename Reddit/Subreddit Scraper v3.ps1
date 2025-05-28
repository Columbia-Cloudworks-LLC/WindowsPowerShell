[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false)]
    [string]$SubReddit = 'all',

    [Parameter(Mandatory = $false)]
    [ValidateSet('hot', 'new', 'top', 'rising', 'controversial')]
    [string]$SortBy = 'hot',

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1000)]
    [int]$Limit = 100
)

# Get the directory of the current script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

##################################################################
## HOW TO USE:
## 1. Make a "reddit.json" file in the same folder as this script.
## 2. Add your clientID and your clientSecret as JSON values
##################################################################
# Path to the JSON config file
$configFile = Join-Path $scriptDir 'reddit.json'

# Read and parse the JSON file
$config = Get-Content $configFile | ConvertFrom-Json

# Assign the values to variables
$clientID = $config.clientID
$clientSecret = $config.clientSecret
$userAgent = 'powershell-scripts/1.0 by viralarchitect'

# Encode the credentials for Basic Authentication
$authInfo = "$clientID`:$clientSecret"
$authBytes = [System.Text.Encoding]::UTF8.GetBytes($authInfo)
$authEncoded = [System.Convert]::ToBase64String($authBytes)

# Obtain an access token from Reddit
$AuthProgressId = 1
Write-Progress -Id $AuthProgressId -Activity "Authenticating with Reddit" -Status "Requesting access token" -PercentComplete 0

$tokenResponse = Invoke-RestMethod -Uri 'https://www.reddit.com/api/v1/access_token' `
    -Method POST `
    -Headers @{
        'Authorization' = "Basic $authEncoded"
        'User-Agent'    = $userAgent
    } `
    -Body @{
        'grant_type' = 'client_credentials'
    }

$accessToken = $tokenResponse.access_token

Write-Progress -Id $AuthProgressId -Activity "Authenticating with Reddit" -Completed

# Function to validate the existence of the subreddit
function Resolve-Subreddit {
    param(
        [string]$subReddit,
        [string]$accessToken,
        [string]$userAgent
    )

    # r/all doesn't have an about page
    if($subReddit -eq 'all') {
        return $true
    }

    $uri = "https://oauth.reddit.com/r/$subReddit/about"

    try {
#        $response = Invoke-RestMethod -Uri $uri -Headers @{
            Invoke-RestMethod -Uri $uri -Headers @{
            'Authorization' = "Bearer $accessToken"
            'User-Agent'    = $userAgent
        }
        return $true
    }
    catch {
        $errorResponse = $_.ErrorDetails.Message | ConvertFrom-Json
        if ($errorResponse.error -eq 404) {
            Write-Error "The subreddit r/$subReddit does not exist."
        } elseif ($errorResponse.error -eq 403) {
            Write-Error "Access to r/$subReddit is forbidden."
        } else {
            Write-Error "Failed to validate subreddit r/$subReddit. Error: $($_.Exception.Message)"
        }
        return $false
    }
}

# Validate the subreddit
$IsValidSubreddit = Resolve-Subreddit -subReddit $SubReddit -accessToken $accessToken -userAgent $userAgent
if (-not $IsValidSubreddit) {
    exit
}

# Function to fetch and format comments
function Get-Comments {
    param (
        [string]$permalink,
        [string]$accessToken,
        [string]$userAgent,
        [ValidateRange(1, 100)]
        [int]$Limit = 10,
        [ValidateSet('confidence', 'top', 'new', 'controversial', 'old', 'random', 'qa', 'live')]
        [string]$CommentSort = 'top',
        [int]$ParentProgressId = 0
    )

    $commentsUri = "https://oauth.reddit.com$($permalink)?limit=$Limit&sort=$CommentSort"

    # Wait to respect rate limits
    Start-Sleep -Milliseconds 1000

    $commentsProgressId = $ParentProgressId + 1

    # Initialize progress for fetching comments
    Write-Progress -Id $commentsProgressId -ParentId $ParentProgressId -Activity "Fetching comments" -Status "Fetching comments for post at $permalink" -PercentComplete 0

    try {
        $commentsResponse = Invoke-RestMethod -Uri $commentsUri `
            -Headers @{
                'Authorization' = "Bearer $accessToken"
                'User-Agent'    = $userAgent
            }
    }
    catch {
        Write-Warning "Failed to fetch comments for post at $permalink. Error: $($_.Exception.Message)"
        Write-Progress -Id $commentsProgressId -ParentId $ParentProgressId -Activity "Fetching comments" -Completed
        return ""
    }

    $comments = $commentsResponse[1].data.children

    $selectedComments = $comments | Where-Object { $_.kind -eq 't1' } | Select-Object -First $Limit

    $commentsArray = @()
    $i = 1
    $TotalComments = $selectedComments.Count

    foreach ($comment in $selectedComments) {
        $percentComplete = ($i / $TotalComments) * 100
        Write-Progress -Id $commentsProgressId -ParentId $ParentProgressId -Activity "Processing comments" -Status "Processing comment $i of $TotalComments" -PercentComplete $percentComplete

        $commentData = $comment.data
        $author = $commentData.author
        $body = $commentData.body

        # Format each comment
        $commentsArray += "Comment $($i): by $author - $body"
        $i++
    }

    # Join the comments with two newlines
    $commentsText = $commentsArray -join "`n`n"

    # Clear the progress bar for comments
    Write-Progress -Id $commentsProgressId -ParentId $ParentProgressId -Activity "Processing comments" -Completed

    return $commentsText
}

# Fetch $Limit of the $sortBy posts from r/$SubReddit
$FetchPostsProgressId = 2
Write-Progress -Id $FetchPostsProgressId -Activity "Fetching posts from r/$SubReddit" -Status "Fetching posts" -PercentComplete 0

$Uri = 'https://oauth.reddit.com/r/' + $SubReddit + '/' + $sortBy + '?limit=' + $Limit
try {
    $response = Invoke-RestMethod -Uri $Uri `
        -Headers @{
            'Authorization' = "Bearer $accessToken"
            'User-Agent'    = $userAgent
        }
}
catch {
    Write-Error "Failed to fetch posts from r/$SubReddit. Error: $($_.Exception.Message)"
    Write-Progress -Id $FetchPostsProgressId -Activity "Fetching posts from r/$SubReddit" -Completed
    exit
}

Write-Progress -Id $FetchPostsProgressId -Activity "Fetching posts from r/$SubReddit" -Completed

# Prepare the data for Excel
$TotalPosts = $response.data.children.Count
$PostIndex = 0
$ProcessPostsProgressId = 3

$data = $response.data.children | ForEach-Object {
    $PostIndex++
    $percentComplete = ($PostIndex / $TotalPosts) * 100

    $post = $_.data
    Write-Progress -Id $ProcessPostsProgressId -Activity "Processing posts" -Status "Processing post $PostIndex of $TotalPosts" -PercentComplete $percentComplete

    # Debugging output
    Write-Host "Processing Post ID: $($post.id), Permalink: $($post.permalink)"

    # Fetch and format the top 10 comments for this post
    $commentsText = Get-Comments -permalink $post.permalink -accessToken $accessToken -userAgent $userAgent -limit 25 -ParentProgressId $ProcessPostsProgressId -CommentSort top

    [PSCustomObject]@{
        'Posted'              = [DateTimeOffset]::FromUnixTimeSeconds($post.created_utc).ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss')
        'Subreddit'           = $post.subreddit_name_prefixed
        'Title'               = $post.title
        'Upvotes'             = $post.ups
        'External URL'        = if ($post.url -match '^/r/') { "https://www.reddit.com$($post.url)" } else { $post.url }
        'Reddit Comments URL' = "https://www.reddit.com$($post.permalink)"
        'Comments'            = $commentsText  # Add the comments here
    }
}

# Clear the progress bar for posts
Write-Progress -Id $ProcessPostsProgressId -Activity "Processing posts" -Completed

# Export the data to an Excel file
$ExportProgressId = 4
Write-Progress -Id $ExportProgressId -Activity "Exporting data to Excel" -Status "Exporting data" -PercentComplete 0

$data | Export-Excel -Path "r_$SubReddit.xlsx" -WorksheetName $sortBy -AutoSize -Append
$data | Export-Excel -Path "r_[CONSOLIDATED].xlsx" -WorksheetName $sortBy -AutoSize -Append

Write-Progress -Id $ExportProgressId -Activity "Exporting data to Excel" -Completed

Write-Host "Data successfully exported to r_$SubReddit.xlsx"