<#
.SYNOPSIS
    Multi-CSV inventory recon with AD, DNS, live checks, OU, patches, reboot time.
.DESCRIPTION
    Adds OU path, patches installed in the last 30 days, last reboot time,
    progress bar, 30-second per-host timeout, and graceful error handling.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string[]]$CsvPath,

    [string]$OutputPath = ".\InventoryRecon_{0:yyyyMMdd_HHmm}.csv" -f (Get-Date),

    [int]$TimeoutSec = 30
)

#region helper functions ------------------------------------------------------
function Get-HostnameColumn   { param($CsvSample) … }         # <- unchanged
function Normalize-Hostname   { param($Name) … }              # <- unchanged

function Invoke-WithTimeout {
    param(
        [ScriptBlock]$ScriptBlock,
        [int]$Timeout = 30
    )
    $job = Start-Job -ScriptBlock $ScriptBlock
    if (Wait-Job $job -Timeout $Timeout) {
        Receive-Job $job -ErrorAction Stop
    } else {
        Stop-Job $job
        throw "Timed out after $Timeout seconds"
    }
}

function Get-CanonicalOUPath {
    param([string]$DistinguishedName)
    # Convert "CN=SRV01,OU=Prod,DC=corp,DC=local" to "corp.local/Prod"
    ($DistinguishedName -split ',')[-1..-2] -join '/' -replace 'DC=',''
}
#endregion -------------------------------------------------------------------

#region gather inventories (same as v1) --------------------------------------
$inventories = @{} ; …                                           # trimmed for brevity
$allHosts    = $inventories.Values | Select-Object -ExpandProperty * | Sort-Object -Unique
#endregion -------------------------------------------------------------------

#region pull AD data once ----------------------------------------------------
$adComputers = Get-ADComputer -Filter 'ObjectClass -eq "computer"' `
                               -Properties OperatingSystem,DistinguishedName |
               Group-Object { $_.Name.ToUpper() } -AsHashTable
#endregion -------------------------------------------------------------------

$total = $allHosts.Count
$index = 0
$results = foreach ($host in $allHosts) {
    $index++
    Write-Progress -Activity "Reconciling hosts" `
                   -Status  "Processing $host ($index of $total)" `
                   -PercentComplete (($index / $total)*100)

    $obj = [ordered]@{
        Hostname   = $host
        InAD       = $false
        OU         = $null
        Online     = $false
        InDNS      = $false
        OS         = $null
        LastBoot   = $null
        Patches30d = $null
        Error      = $null
    }

    foreach ($csv in $CsvPath) {  # presence flags
        $flag = 'In_' + (Split-Path $csv -Leaf).Replace('.','_')
        $obj[$flag] = $inventories[$csv] -contains $host
    }

    # --- AD data ------------------------------------------------------------
    if ($adComputers.ContainsKey($host)) {
        $obj.InAD   = $true
        $comp       = $adComputers[$host]
        $obj.OS     = $comp.OperatingSystem
        $obj.OU     = Get-CanonicalOUPath $comp.DistinguishedName
    }

    try {
        # Use wrapper so one bad call doesn’t burn the loop ------------------
        Invoke-WithTimeout -Timeout $TimeoutSec -ScriptBlock {
            param($h,$ref)  # $using:host etc isn't available inside Start-Job in 5.x
            $result = [ordered]@{}
            # Ping
            $result.Online = Test-Connection -ComputerName $h -Count 1 -Quiet -ErrorAction Stop
            # DNS
            $result.InDNS  = (Resolve-DnsName $h -ErrorAction Stop) -ne $null
            if ($result.Online) {
                # OS + last reboot
                $os = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $h -ErrorAction Stop
                $result.OS       = $os.Caption
                $result.LastBoot = $os.LastBootUpTime
                # Patches last 30 days
                $since = (Get-Date).AddDays(-30)
                $hf = Get-HotFix -ComputerName $h -ErrorAction Stop |
                      Where-Object { $_.InstalledOn -gt $since }
                $result.Patches30d = ($hf | Select-Object -ExpandProperty HotFixID) -join '; '
            }
            return $result
        } -ArgumentList $host |
        ForEach-Object { foreach ($k in $_.PSObject.Properties) { $obj[$k.Name] = $k.Value } }
    } catch {
        $obj.Error = $_.Exception.Message
    }

    [pscustomobject]$obj
}

$results | Export-Csv -NoTypeInformation -Path $OutputPath
Write-Host "Done. Report: $OutputPath"
