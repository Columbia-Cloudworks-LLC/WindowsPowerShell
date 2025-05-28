<#
.SYNOPSIS
  Categorizes Vortex plugins into official Starfield plugins, managed plugins (with metadata), and unmanaged mods.
  For each unmanaged plugin, the script constructs a manual search URL for Nexus Mods.

.DESCRIPTION
  This script reads a Vortex-exported JSON file (an array of plugin objects) and separates plugins into three categories:
    1. Official Starfield Plugins – determined via a hardcoded list.
    2. Plugins Managed by Vortex – those with a "modId" property.
    3. Unmanaged Plugins – those lacking "modId" and not in the official list.
  
  For each unmanaged plugin, the script:
    - Constructs a manual search URL for Nexus Mods using the slugified plugin name.
    - Constructs a manual search URL for Bethesda Creations using the slugified plugin name.
    - Outputs the manual search URL for both so the user can copy-paste it into a browser.
  
  Errors (such as file not found) are logged to a log file in the script directory.

.PARAMETER InputFile
  Path to the JSON file exported from Vortex. To export your load order from Vortex, go to the "Load Order" tab, click the down arrow next to the "Load Order" button, and select "Export Load Order". This is a required parameter.

.PARAMETER OutputFile
  Path where the text report should be saved. Defaults to a timestamped file in the same directory as the InputFile.

.PARAMETER StarfieldDataFolder
  Path to the Starfield “Data” folder containing the plugin files. Defaults to "D:\SteamLibrary\steamapps\common\Starfield\Data". You will likely need to change this to match your Starfield installation. Encase the path in double quotes to ensure the full path is provided to the script.

.PARAMETER Debug
  Switch to enable verbose output for debugging purposes.

.NOTES
  This script helps users with a mix of creations and Nexus Mods to easily search their creations on Nexus Mods or Bethesda Creations so they can be managed with Vortex or another mod manager instead of Bethesda Creations.
#>

param(
    [string]$InputFile,
    [string]$OutputFile = "$(Split-Path -Path $InputFile)\Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt",
    [string]$StarfieldDataFolder = "D:\SteamLibrary\steamapps\common\Starfield\Data",
    [switch]$Debug
)

# Set up a log file (errors appended) in the script directory
$LogFile = Join-Path $PSScriptRoot "StarfieldPluginScript.log"

function slugifyNexus {
    param (
        [string]$text
    )
    $text = $text -replace "\.esm$", ""
    $text = $text -replace "\.esp$", ""
    $text = $text -replace "\.esl$", ""
    $text = $text -replace "[^\w\s]", ""
    $text = $text -replace "\s+", " "
    $text = $text -replace "^\W+|\W+$", ""
    return $text.ToLower()
}

function slugifyBethesda {
    param (
        [string]$text
    )
    $text = $text -replace "\.esm$", ""
    $text = $text -replace "\.esp$", ""
    $text = $text -replace "\.esl$", ""
    $text = $text -replace "[^\w\s]", ""
    $text = $text -replace "\s+", "+"
    $text = $text -replace "^\W+|\W+$", ""
    return $text.ToLower()
}

function Log-Error {
    param (
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - ERROR: $Message"
    Write-Host "$timestamp - ERROR: $Message" -ForegroundColor Red
    Add-Content -Path $LogFile -Value $logMessage
}

if($Debug) {
    $originalDebugPreference = $DebugPreference
    $DebugPreference = "Continue"
}

# Read and parse the Vortex-exported JSON file
try {
    if (-not (Test-Path $InputFile)) {
        throw "Input JSON file not found: $InputFile"
    }
    $jsonContent = Get-Content -Path $InputFile -Raw
    $pluginList = $jsonContent | ConvertFrom-Json
}
catch {
    Log-Error "Failed to read or parse JSON file. $_"
    exit 1
}

if (-not ($pluginList -is [System.Collections.IEnumerable])) {
    Log-Error "Unexpected JSON structure: Expected an array of plugin objects."
    exit 1
}

# Define the hardcoded list of official Starfield plugins (case-insensitive)
$OfficialListNames = @(
    "Starfield.esm",
    "BlueprintShips-Starfield.esm",
    "OldMars.esm",
    "Constellation.esm",
    "SFBGS003.esm",
    "SFBGS004.esm",
    "SFBGS006.esm",
    "SFBGS007.esm",
    "SFBGS008.esm",
    "sfta01.esm",
    "sfbgs00c.esm",
    "sfbgs00b.esm",
    "sfbgs024.esm",
    "kgcdoom.esm",
    "sfbgs009.esm",
    "sfbgs00a_a.esm",
    "sfbgs00a_d.esm",
    "sfbgs00a_e.esm",
    "sfbgs00a_f.esm",
    "sfbgs00a_g.esm",
    "sfbgs00a_i.esm",
    "sfbgs00a_j.esm",
    "sfbgs02a_a.esm",
    "sfbgs02b_a.esm",
    "sfbgs00f_a.esm",
    "sfbgs019.esm",
    "sfbgs021.esm",
    "sfbgs031.esm",
    "sfbgs023.esm",
    "sfbgs01c.esm",
    "sfbgs00e.esm",
    "sfbgs01b.esm"
)

# Initialize arrays for categorized plugins
$officialPlugins = @()
$managedPlugins = @()
$unmanagedPlugins = @()

foreach ($plugin in $pluginList) {
    $pluginName = $plugin.name
    if ([string]::IsNullOrEmpty($pluginName)) { continue }
    if ($OfficialListNames -contains $pluginName) {
        $officialPlugins += $pluginName
    }
    elseif ($plugin.PSObject.Properties.Name -contains 'modId' -and $plugin.modId) {
        $managedPlugins += $pluginName
    }
    else {
        $unmanagedPlugins += $pluginName
    }
}

# Prepare the output report
$outputLines = @()

# Section 1: Official Starfield Plugins
$outputLines += "Official Starfield Plugins:"
$outputLines += ("-" * 50)
if ($officialPlugins.Count -gt 0) {
    foreach ($p in $officialPlugins) {
        $outputLines += " - $p"
    }
}
else {
    $outputLines += " - None found."
}
$outputLines += ""

# Section 2: Plugins Managed by Vortex (with metadata)
$outputLines += "Plugins Managed by Vortex (with metadata):"
$outputLines += ("-" * 50)
if ($managedPlugins.Count -gt 0) {
    foreach ($p in $managedPlugins) {
        $outputLines += " - $p"
    }
}
else {
    $outputLines += " - None found."
}
$outputLines += ""

# Check if any Unmanaged Plugins have the same plugin name as a managed plugin (case-insensitive)
# If so, remove it from the unmanaged list
foreach ($plugin in $unmanagedPlugins) {
    if ($managedPlugins -contains $plugin) {
        $unmanagedPlugins = $unmanagedPlugins | Where-Object { $_ -ne $plugin }
    }
}

# Section 3: Unmanaged Plugins (assumed mods) with manual search URL
$outputLines += "Unmanaged Plugins (assumed mods):"
$outputLines += ("-" * 50)
if ($unmanagedPlugins.Count -gt 0) {
    foreach ($plugin in $unmanagedPlugins) {
        $outputLines += " - $plugin"
        $manualSearchUrlNexus = "https://next.nexusmods.com/starfield/mods?keyword=$(slugifyNexus $plugin)&sort=endorsements"
        # https://creations.bethesda.net/en/starfield/all?text=test+testing
        $manualSearchUrlBethesda = "https://creations.bethesda.net/en/starfield/all?text=$(slugifyBethesda $plugin)"
        $outputLines += "     Search NexusMods         : $manualSearchUrlNexus"
        $outputLines += "     Search Bethesda Creations: $manualSearchUrlBethesda"
    }
}
else {
    $outputLines += " - None found."
}

# Write the report to file and output to console
try {
    $outputLines | Out-File -FilePath $OutputFile -Encoding UTF8 -Force
    $outputLines | ForEach-Object { Write-Host $_ }
    Write-Host "Report generated successfully: $OutputFile" -ForegroundColor Green
}
catch {
    Log-Error "Failed to write output file. $_"
    exit 1
}

if($Debug) {
    $DebugPreference = $originalDebugPreference
}