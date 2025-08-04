# Constants
$CabFile = Join-Path -Path $PSScriptRoot -ChildPath 'wsusscn2.cab'
$CsvOutput = Join-Path -Path $PSScriptRoot -ChildPath "PatchReport_$($env:COMPUTERNAME).csv"

# Check if running as administrator and restart if not
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script requires administrator privileges. Restarting with elevated permissions..."
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Verify CAB file exists
if (-not (Test-Path -Path $CabFile)) {
    Write-Error "CAB file ($CabFile) not found. Please ensure it's downloaded first."
    exit
}

# Setup Update Session and Offline Scanner
$Session = New-Object -ComObject Microsoft.Update.Session
$SvcMgr = New-Object -ComObject Microsoft.Update.ServiceManager
$Svc = $SvcMgr.AddScanPackageService('Offline Scan', $CabFile)

$Searcher = $Session.CreateUpdateSearcher()
$Searcher.ServerSelection = 3 # Use Offline Scan
$Searcher.ServiceID = $Svc.ServiceID

# Search for missing updates
Write-Output "Scanning for applicable updates using $CabFile..."
$SearchResult = $Searcher.Search("IsInstalled=0 or IsInstalled=1")

# Collect Data
$Report = foreach ($Update in $SearchResult.Updates) {
    [PSCustomObject]@{
        Hostname            = $env:COMPUTERNAME
        OSVersion           = (Get-CimInstance Win32_OperatingSystem).Caption
        KBArticleIDs        = ($Update.KBArticleIDs | ForEach-Object { "KB$_" }) -join ','
        Title               = $Update.Title
        SecurityBulletinIDs = ($Update.SecurityBulletinIDs -join ',')
        ReleaseDate         = $Update.LastDeploymentChangeTime.ToString('yyyy-MM-dd')
        InstalledDate       = if ($Update.IsInstalled) { $Update.LastDeploymentChangeTime.ToString('yyyy-MM-dd') } else { "" }
        IsInstalled         = $Update.IsInstalled
        LastChecked         = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    }
}

# Export results to CSV
try {
    $Report | Export-Csv -Path $CsvOutput -NoTypeInformation -Force
    Write-Output "Patch report generated: $CsvOutput"
}
catch {
    Write-Error "Cannot write to file '$CsvOutput'. The file may be open in another application. Please close the file and try again."
    exit 1
}
