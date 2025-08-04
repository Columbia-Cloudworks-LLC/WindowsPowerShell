[CmdletBinding()]
param(
    [string]$Symbol = "MSFT"
)

# 1. Load your API key from JSON
$keyFilePath = ".\AlphaVantage.api.key.json"
if (-Not (Test-Path $keyFilePath)) {
    Write-Error "API key file not found at path: $keyFilePath"
    exit
} elseif (-not (Get-Content -Path $keyFilePath -Raw)) {
    Write-Error "API key file is empty. Please provide a valid API key."
    exit
} else {
    Write-Debug "API key file loaded successfully."
}

$keyContent = Get-Content -Path $keyFilePath -Raw | ConvertFrom-Json
$ApiKey = $keyContent.AlphaVantageApiKey

# 2. Build the API URL for TIME_SERIES_DAILY
$ApiUrl = "https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol=$Symbol&apikey=$ApiKey"

# 3. Invoke the REST method to get stock data
try {
    $response = Invoke-RestMethod -Uri $ApiUrl -Method Get -ErrorAction Stop
} catch {
    Write-Error "Error fetching data from Alpha Vantage: $_"
    exit
}

# 4. Parse the JSON response to extract the 'Time Series (Daily)' data
if ($response.'Time Series (Daily)') {
    Write-Debug "Data retrieved successfully."
    $dailyData = $response.'Time Series (Daily)'
} else {
    Write-Error "The response did not contain 'Time Series (Daily)' data. Please verify the API key and parameters."
    exit
}

# Write-Debug "Response: $($response | ConvertTo-Json -Depth 3)"
$dailyData | Get-Member -MemberType Properties

$dailyData | Sort-Object -Property Name -Descending | Format-Table -AutoSize
# 6. Sort the data by date descending and display as a table
$stockData | Sort-Object Date -Descending | Format-Table -AutoSize
