param (
    [Parameter(Mandatory = $true)]
    [string[]]$OS
)

# Function to fetch updates for a specific OS
function Get-UpdatesForOS {
    param (
        [string]$OperatingSystem
    )

    Write-Host "Fetching updates for $OperatingSystem..."
    # Base URL for Microsoft Update Catalog
    $BaseUrl = "https://www.catalog.update.microsoft.com/Search.aspx?q="

    # Encode the operating system query
    $SearchQuery = [System.Web.HttpUtility]::UrlEncode($OperatingSystem)

    # Construct search URL
    $Url = "$BaseUrl$SearchQuery"

    # Fetch the search results
    $WebResponse = Invoke-WebRequest -Uri $Url -UseBasicParsing

    # Parse the results
    if ($WebResponse -and $WebResponse.Content) {
        $WebMatches = Select-String -InputObject $WebResponse.Content -Pattern "updateTitle.*href.*"
        $Updates = @()

        foreach ($Match in $WebMatches) {
            $Title = $Match.Line -replace ".*updateTitle.*?>", "" -replace "<.*", ""
            $UrlMatch = $Match.Line -match 'href="([^"]+)"' | Out-Null
            $DownloadUrl = $WebMatches.WebMatches.Groups[1].Value
            $Updates += [PSCustomObject]@{
                Title       = $Title
                DownloadUrl = $DownloadUrl
            }
        }

        return $Updates
    } else {
        Write-Warning "No updates found for $OperatingSystem."
        return @()
    }
}

# Iterate over each OS and fetch updates
$Results = @()
foreach ($OsName in $OS) {
    $Updates = Get-UpdatesForOS -OperatingSystem $OsName
    $Results += $Updates
}

# Output the results
if ($Results.Count -gt 0) {
    $Results | Format-Table -AutoSize
} else {
    Write-Host "No updates found for the specified operating systems."
}
