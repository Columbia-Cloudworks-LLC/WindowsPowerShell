# Requires -Version 5.1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the form
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Patch Report Generator"
$Form.Size = New-Object System.Drawing.Size(400, 500)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = "FixedDialog"
$Form.MaximizeBox = $false
$Form.MinimizeBox = $false

# Account Name Label and TextBox
$AccountNameLabel = New-Object System.Windows.Forms.Label
$AccountNameLabel.Location = New-Object System.Drawing.Point(10, 10)
$AccountNameLabel.Size = New-Object System.Drawing.Size(100, 20)
$AccountNameLabel.Text = "Account Name:"
$Form.Controls.Add($AccountNameLabel)

$AccountNameTextBox = New-Object System.Windows.Forms.TextBox
$AccountNameTextBox.Location = New-Object System.Drawing.Point(120, 10)
$AccountNameTextBox.Size = New-Object System.Drawing.Size(250, 20)
$Form.Controls.Add($AccountNameTextBox)

# Change Number Label and TextBox
$ChangeNumberLabel = New-Object System.Windows.Forms.Label
$ChangeNumberLabel.Location = New-Object System.Drawing.Point(10, 40)
$ChangeNumberLabel.Size = New-Object System.Drawing.Size(100, 20)
$ChangeNumberLabel.Text = "Change Number:"
$Form.Controls.Add($ChangeNumberLabel)

$ChangeNumberTextBox = New-Object System.Windows.Forms.TextBox
$ChangeNumberTextBox.Location = New-Object System.Drawing.Point(120, 40)
$ChangeNumberTextBox.Size = New-Object System.Drawing.Size(250, 20)
$Form.Controls.Add($ChangeNumberTextBox)

# Server List Label and TextBox
$ServerListLabel = New-Object System.Windows.Forms.Label
$ServerListLabel.Location = New-Object System.Drawing.Point(10, 70)
$ServerListLabel.Size = New-Object System.Drawing.Size(100, 20)
$ServerListLabel.Text = "Server List:"
$Form.Controls.Add($ServerListLabel)

$ServerListTextBox = New-Object System.Windows.Forms.TextBox
$ServerListTextBox.Location = New-Object System.Drawing.Point(120, 70)
$ServerListTextBox.Size = New-Object System.Drawing.Size(250, 150)
$ServerListTextBox.Multiline = $true
$ServerListTextBox.ScrollBars = "Vertical"
$Form.Controls.Add($ServerListTextBox)

# KB List Label and TextBox
$KBListLabel = New-Object System.Windows.Forms.Label
$KBListLabel.Location = New-Object System.Drawing.Point(10, 230)
$KBListLabel.Size = New-Object System.Drawing.Size(100, 20)
$KBListLabel.Text = "List of KBs:"
$Form.Controls.Add($KBListLabel)

$KBListTextBox = New-Object System.Windows.Forms.TextBox
$KBListTextBox.Location = New-Object System.Drawing.Point(120, 230)
$KBListTextBox.Size = New-Object System.Drawing.Size(250, 150)
$KBListTextBox.Multiline = $true
$KBListTextBox.ScrollBars = "Vertical"
$Form.Controls.Add($KBListTextBox)

# Generate Report Button
$GenerateButton = New-Object System.Windows.Forms.Button
$GenerateButton.Location = New-Object System.Drawing.Point(150, 400)
$GenerateButton.Size = New-Object System.Drawing.Size(100, 30)
$GenerateButton.Text = "Generate Report"
$Form.Controls.Add($GenerateButton)

# Action to perform when the button is clicked
$GenerateButton.Add_Click({
    # Get user input from the text boxes
    $AccountName = $AccountNameTextBox.Text.Trim()
    $ChangeNumber = $ChangeNumberTextBox.Text.Trim()
    $ServerList = $ServerListTextBox.Text.Trim() -split "`n" | Where-Object { $_ }
    $KBList = $KBListTextBox.Text.Trim() -split "`n" | Where-Object { $_ }

    # Input validation (basic check)
    if ([string]::IsNullOrWhiteSpace($AccountName) -or [string]::IsNullOrWhiteSpace($ChangeNumber) -or $ServerList.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please enter Account Name, Change Number, and at least one server name.", "Missing Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    # Data collection
    $ReportData = @()
    $ScannedOn = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ") # ISO 8601 UTC format
    $ScannedBy = "$env:USERDOMAIN\$env:USERNAME" # Domain\User format

    foreach ($server in $ServerList) {
        Write-Host "Processing server: $server"

        try {
            # Get installed hotfixes
            $Hotfixes = Get-HotFix -ComputerName $server -ErrorAction Stop

            # Get last reboot time
            $LastBootUpTime = (Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $server -ErrorAction Stop).LastBootUpTime

            foreach ($hotfix in $Hotfixes) {
                # Check if the KB is in the provided list
                $InKBList = $false
                if ($KBList.Count -gt 0 -and $KBList -contains $hotfix.HotFixID) {
                     $InKBList = $true
                }

                # Create a custom object for each hotfix
                $ReportObject = [PSCustomObject]@{
                    "Account Name" = $AccountName
                    "Change Number" = $ChangeNumber
                    "Hostname" = $server
                    "KB Number" = $hotfix.HotFixID
                    "Installed On" = $hotfix.InstalledOn
                    "Last Reboot Time" = $LastBootUpTime
                    "Scanned On" = $ScannedOn
                    "Scanned By" = $ScannedBy
                    "In KB List?" = $InKBList
                }
                $ReportData += $ReportObject
            }
        } catch {
            Write-Warning "Failed to connect to or gather information from server: $server. Error: $($_.Exception.Message)"
        }
    }

    # Generate timestamp for the output file
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputPath = "$([Environment]::GetFolderPath("Desktop"))\PatchReport_$Timestamp.csv"

    # Export to CSV
    if ($ReportData.Count -gt 0) {
        $ReportData | Export-Csv -Path $OutputPath -NoTypeInformation
        [System.Windows.Forms.MessageBox]::Show("Patch report generated successfully: $OutputPath", "Report Generated", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } else {
        [System.Windows.Forms.MessageBox]::Show("No patch information found for the specified servers.", "Report Generated", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
})

# Show the form
$Form.ShowDialog()
