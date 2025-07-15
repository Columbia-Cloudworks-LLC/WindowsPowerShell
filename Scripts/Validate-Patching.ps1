<#
.SYNOPSIS
    Validates patching on Windows servers and generates a CSV report.
.DESCRIPTION
    This script validates patching on a list of Windows servers by checking:
    - If servers were rebooted after patches were installed
    - If patches were installed in the last 24 hours
    - If servers are online and accessible
    
    The script works in restrictive environments without requiring WinRM or Invoke-Command.
.PARAMETER None
    All parameters are collected via GUI.
.EXAMPLE
    .\Validate-Patching.ps1
    Runs the patching validation script with GUI input.
#>

[CmdletBinding()]
param()

# Script configuration
$ScriptVersion = "1.0.0"
$ErrorLogFile = Join-Path $PSScriptRoot "PatchingValidation_Errors.log"

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to self-elevate the script
function Start-ElevatedScript {
    try {
        $scriptPath = $MyInvocation.MyCommand.Path
        Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs -Wait
        exit
    }
    catch {
        Write-Error "Failed to elevate script. Please run as Administrator."
        exit 1
    }
}

# Function to create and show the GUI
function Show-InputGUI {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Patching Validation - Input Required"
    $form.Size = New-Object System.Drawing.Size(500, 400)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    # Customer Name Label and TextBox
    $lblCustomerName = New-Object System.Windows.Forms.Label
    $lblCustomerName.Location = New-Object System.Drawing.Point(20, 20)
    $lblCustomerName.Size = New-Object System.Drawing.Size(120, 20)
    $lblCustomerName.Text = "Customer Name:"
    $form.Controls.Add($lblCustomerName)

    $txtCustomerName = New-Object System.Windows.Forms.TextBox
    $txtCustomerName.Location = New-Object System.Drawing.Point(150, 20)
    $txtCustomerName.Size = New-Object System.Drawing.Size(300, 20)
    $form.Controls.Add($txtCustomerName)

    # Change Number Label and TextBox
    $lblChangeNumber = New-Object System.Windows.Forms.Label
    $lblChangeNumber.Location = New-Object System.Drawing.Point(20, 50)
    $lblChangeNumber.Size = New-Object System.Drawing.Size(120, 20)
    $lblChangeNumber.Text = "Change Number:"
    $form.Controls.Add($lblChangeNumber)

    $txtChangeNumber = New-Object System.Windows.Forms.TextBox
    $txtChangeNumber.Location = New-Object System.Drawing.Point(150, 50)
    $txtChangeNumber.Size = New-Object System.Drawing.Size(300, 20)
    $form.Controls.Add($txtChangeNumber)

    # Servers Label and TextBox
    $lblServers = New-Object System.Windows.Forms.Label
    $lblServers.Location = New-Object System.Drawing.Point(20, 80)
    $lblServers.Size = New-Object System.Drawing.Size(120, 20)
    $lblServers.Text = "Servers (one per line):"
    $form.Controls.Add($lblServers)

    $txtServers = New-Object System.Windows.Forms.TextBox
    $txtServers.Location = New-Object System.Drawing.Point(150, 80)
    $txtServers.Size = New-Object System.Drawing.Size(300, 200)
    $txtServers.Multiline = $true
    $txtServers.ScrollBars = "Vertical"
    $form.Controls.Add($txtServers)

    # OK Button
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Location = New-Object System.Drawing.Point(200, 300)
    $btnOK.Size = New-Object System.Drawing.Size(75, 23)
    $btnOK.Text = "OK"
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $btnOK
    $form.Controls.Add($btnOK)

    # Cancel Button
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Location = New-Object System.Drawing.Point(285, 300)
    $btnCancel.Size = New-Object System.Drawing.Size(75, 23)
    $btnCancel.Text = "Cancel"
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $btnCancel
    $form.Controls.Add($btnCancel)

    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return @{
            CustomerName = $txtCustomerName.Text.Trim()
            ChangeNumber = $txtChangeNumber.Text.Trim()
            Servers = $txtServers.Text.Trim() -split "`r?`n" | Where-Object { $_.Trim() -ne "" }
        }
    }
    else {
        return $null
    }
}

# Function to get server information without WinRM
function Get-ServerInfo {
    param(
        [string]$ServerName
    )
    
    try {
        # Test if server is reachable
        $ping = Test-Connection -ComputerName $ServerName -Count 1 -Quiet
        if (-not $ping) {
            throw "Server is not reachable"
        }

        # Get IPv4 address
        $ipAddress = [System.Net.Dns]::GetHostAddresses($ServerName) | 
                    Where-Object { $_.AddressFamily -eq "InterNetwork" } | 
                    Select-Object -First 1 -ExpandProperty IPAddressToString

        # Get FQDN
        $fqdn = [System.Net.Dns]::GetHostEntry($ServerName).HostName

        # Get OS version using WMI (works without WinRM)
        $osInfo = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ServerName -ErrorAction Stop
        $osVersion = $osInfo.Caption + " " + $osInfo.Version

        # Get last reboot time
        $lastReboot = $osInfo.ConvertToDateTime($osInfo.LastBootUpTime)

        # Get installed patches from registry (works without WinRM)
        $patches = @()
        try {
            $regKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey("LocalMachine", $ServerName)
            $uninstallKey = $regKey.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall")
            
            foreach ($subKeyName in $uninstallKey.GetSubKeyNames()) {
                $subKey = $uninstallKey.OpenSubKey($subKeyName)
                $displayName = $subKey.GetValue("DisplayName")
                $installDate = $subKey.GetValue("InstallDate")
                
                if ($displayName -and $displayName -like "*KB*" -and $installDate) {
                    $patches += [PSCustomObject]@{
                        KB = $displayName
                        InstalledOn = $installDate
                    }
                }
            }
        }
        catch {
            Write-Warning "Could not retrieve patch information from registry for $ServerName"
        }

        return @{
            Success = $true
            IPv4Address = $ipAddress
            FQDN = $fqdn
            OSVersion = $osVersion
            LastReboot = $lastReboot
            Patches = $patches
        }
    }
    catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# Function to validate patching
function Test-PatchingValidation {
    param(
        [object]$ServerInfo,
        [datetime]$LastReboot,
        [array]$Patches
    )
    
    $validation = @{
        RebootRequired = $false
        NoRecentPatches = $false
        Issues = @()
    }

    # Check if patches were installed in last 24 hours
    $recentPatches = $Patches | Where-Object { 
        $installDate = [datetime]::ParseExact($_.InstalledOn, "yyyyMMdd", $null)
        $installDate -gt (Get-Date).AddDays(-1)
    }

    if ($recentPatches.Count -eq 0) {
        $validation.NoRecentPatches = $true
        $validation.Issues += "No patches installed in last 24 hours"
    }

    # Check if reboot is required after recent patches
    if ($recentPatches.Count -gt 0) {
        $latestPatchDate = ($recentPatches | ForEach-Object { 
            [datetime]::ParseExact($_.InstalledOn, "yyyyMMdd", $null) 
        } | Sort-Object -Descending | Select-Object -First 1)
        
        if ($LastReboot -lt $latestPatchDate) {
            $validation.RebootRequired = $true
            $validation.Issues += "Reboot required after patch installation"
        }
    }

    return $validation
}

# Function to write error to log file
function Write-ErrorLog {
    param(
        [string]$Message,
        [string]$ServerName = ""
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $ServerName`: $Message"
    Add-Content -Path $ErrorLogFile -Value $logEntry
}

# Main execution
function Main {
    Write-Host "Patching Validation Script v$ScriptVersion" -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green

    # Check if running as administrator
    if (-not (Test-Administrator)) {
        Write-Host "Script requires administrative privileges. Elevating..." -ForegroundColor Yellow
        Start-ElevatedScript
        return
    }

    # Show GUI to collect user information
    Write-Host "Opening input dialog..." -ForegroundColor Cyan
    $userInput = Show-InputGUI

    if (-not $userInput) {
        Write-Host "Operation cancelled by user." -ForegroundColor Yellow
        return
    }

    # Validate input
    if ([string]::IsNullOrWhiteSpace($userInput.CustomerName)) {
        Write-Error "Customer Name is required."
        return
    }

    if ([string]::IsNullOrWhiteSpace($userInput.ChangeNumber)) {
        Write-Error "Change Number is required."
        return
    }

    if ($userInput.Servers.Count -eq 0) {
        Write-Error "At least one server is required."
        return
    }

    # Initialize error tracking
    $script:HasErrors = $false

    # Create output file
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $accountName = $env:USERNAME
    $outputFile = Join-Path $env:USERPROFILE "Desktop" "${accountName}_${($userInput.ChangeNumber)}_Patches_${timestamp}.csv"

    # Initialize CSV output
    $csvHeaders = @(
        "Customer Name",
        "Change Number", 
        "Hostname",
        "IPv4 Address",
        "Fully-Qualified Domain Name",
        "Operating System",
        "KB Number",
        "Installed On",
        "Last Reboot",
        "Validation Issues"
    )

    $csvData = @()

    Write-Host "`nStarting server validation..." -ForegroundColor Cyan
    Write-Host "Processing $($userInput.Servers.Count) servers..." -ForegroundColor Cyan

    # Process each server
    for ($i = 0; $i -lt $userInput.Servers.Count; $i++) {
        $server = $userInput.Servers[$i]
        $progressPercent = (($i + 1) / $userInput.Servers.Count) * 100
        
        Write-Progress -Activity "Validating Patching" -Status "Processing $server" -PercentComplete $progressPercent
        
        Write-Host "Processing server: $server" -ForegroundColor Yellow

        $serverInfo = Get-ServerInfo -ServerName $server

        if ($serverInfo.Success) {
            Write-Host "  [OK] Server is online" -ForegroundColor Green
            
            # Validate patching
            $validation = Test-PatchingValidation -ServerInfo $serverInfo -LastReboot $serverInfo.LastReboot -Patches $serverInfo.Patches
            
            # Add each patch to CSV
            if ($serverInfo.Patches.Count -gt 0) {
                foreach ($patch in $serverInfo.Patches) {
                    $csvData += [PSCustomObject]@{
                        "Customer Name" = $userInput.CustomerName
                        "Change Number" = $userInput.ChangeNumber
                        "Hostname" = $server
                        "IPv4 Address" = $serverInfo.IPv4Address
                        "Fully-Qualified Domain Name" = $serverInfo.FQDN
                        "Operating System" = $serverInfo.OSVersion
                        "KB Number" = $patch.KB
                        "Installed On" = $patch.InstalledOn
                        "Last Reboot" = $serverInfo.LastReboot.ToString("yyyy-MM-dd HH:mm:ss")
                        "Validation Issues" = ($validation.Issues -join "; ")
                    }
                }
            }
            else {
                # Add server entry even if no patches found
                $csvData += [PSCustomObject]@{
                    "Customer Name" = $userInput.CustomerName
                    "Change Number" = $userInput.ChangeNumber
                    "Hostname" = $server
                    "IPv4 Address" = $serverInfo.IPv4Address
                    "Fully-Qualified Domain Name" = $serverInfo.FQDN
                    "Operating System" = $serverInfo.OSVersion
                    "KB Number" = ""
                    "Installed On" = ""
                    "Last Reboot" = $serverInfo.LastReboot.ToString("yyyy-MM-dd HH:mm:ss")
                    "Validation Issues" = ($validation.Issues -join "; ")
                }
            }

            # Display validation issues
            if ($validation.Issues.Count -gt 0) {
                Write-Host "  [WARNING] Issues found:" -ForegroundColor Red
                foreach ($issue in $validation.Issues) {
                    Write-Host "    - $issue" -ForegroundColor Red
                }
            }
        }
        else {
            Write-Host "  [ERROR] $($serverInfo.Error)" -ForegroundColor Red
            Write-ErrorLog -Message $serverInfo.Error -ServerName $server
            $script:HasErrors = $true
        }
    }

    Write-Progress -Activity "Validating Patching" -Completed

    # Write CSV file
    try {
        $csvData | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
        Write-Host "`n[OK] Report generated successfully: $outputFile" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to write CSV file: $($_.Exception.Message)"
        Write-ErrorLog -Message "Failed to write CSV file: $($_.Exception.Message)"
        $script:HasErrors = $true
    }

    # Open error log if there were errors
    if ($script:HasErrors) {
        Write-Host "`n[WARNING] Errors occurred during execution. Opening error log..." -ForegroundColor Yellow
        Start-Process notepad.exe -ArgumentList $ErrorLogFile
    }

    Write-Host "`nScript execution completed." -ForegroundColor Green
}

# Run the main function
Main 