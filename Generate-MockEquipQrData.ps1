param(
    [int]$Rows = 25,
    [string]$Output = "equipment_mockdata.csv",
    [int]$Seed = 42
)

# For idempotence
$null = [System.Random]::new($Seed)

$random = [System.Random]::new($Seed)

$equipmentTypes = @(
    @{Name="HD Forklift"; Models=@("FLX-2000","FLX-1500","FLX-3500"); Desc="Heavy-duty forklift with side-shift"},
    @{Name="Portable Generator"; Models=@("G3500","G5500","G7000"); Desc="Inverter generator for backup power"},
    @{Name="Excavator XR"; Models=@("XR50","XR80","XR100"); Desc="Mini-excavator with hydraulic thumb"},
    @{Name="Diesel Compressor"; Models=@("DCP-120","DCP-200","DCP-150"); Desc="Portable diesel air compressor"},
    @{Name="Mobile Crane"; Models=@("MC-30","MC-50","MC-75"); Desc="Telescopic boom crane"},
    @{Name="Weld Master"; Models=@("WM200","WM350","WM500"); Desc="MIG welder with spool gun"},
    @{Name="Gas Pressure Washer"; Models=@("GPW-4000","GPW-3500","GPW-5000"); Desc="Heavy-duty pressure washer"},
    @{Name="Backhoe Loader"; Models=@("BL85","BL90","BL100"); Desc="Loader/backhoe combo with extendahoe"},
    @{Name="Light Tower"; Models=@("PLT-800","PLT-1000","PLT-1200"); Desc="LED light tower with diesel gen"},
    @{Name="Hydraulic Breaker"; Models=@("HBX-45","HBX-50","HBX-70"); Desc="Hydraulic hammer for excavators"}
)

$manufacturers = @("UniLift", "Generac", "Komatsu", "Atlas Copco", "Grove", "Lincoln Electric", "Kärcher", "John Deere", "Bosch", "Ingersoll Rand", "Caterpillar", "Volvo", "SANY", "Bobcat", "JCB")
$statuses = @("Active", "Inactive", "Maintenance")
$locations = @(
    "Houston, TX","Dallas, TX","Chicago, IL","New York, NY","Los Angeles, CA",
    "Phoenix, AZ","Miami, FL","Atlanta, GA","Seattle, WA","Denver, CO",
    "Charlotte, NC","Nashville, TN","Cleveland, OH","Portland, OR","Kansas City, MO"
)

function Get-RandomSerial {
    param([string]$prefix)
    $alphanum = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    $sn = ($prefix + "-")
    for ($i=0; $i -lt 8; $i++) {
        $sn += $alphanum[$random.Next(0,$alphanum.Length)]
    }
    return $sn
}

function Get-RandomDate {
    param([datetime]$start, [datetime]$end)
    $range = ($end - $start).Days
    return $start.AddDays($random.Next(0, $range))
}

$rowsOut = @()

for ($i=1; $i -le $Rows; $i++) {
    $equip = $equipmentTypes[$random.Next(0,$equipmentTypes.Count)]
    $manufacturer = $manufacturers[$random.Next(0,$manufacturers.Count)]
    $model = $equip.Models[$random.Next(0,$equip.Models.Count)]
    $serial = Get-RandomSerial ($model.Substring(0,2))
    $status = $statuses[$random.Next(0,$statuses.Count)]
    $location = $locations[$random.Next(0,$locations.Count)]
    $installDate = Get-RandomDate -start (Get-Date "2021-01-01") -end (Get-Date "2024-12-31")
    $warrantyYears = $random.Next(1,4) # 1-3 years warranty
    $warrantyExpire = $installDate.AddYears($warrantyYears)
    $desc = "{0} ({1} model), {2}" -f $equip.Desc, $model, (Get-Random -InputObject @(
        "max load " + $random.Next(2,12)*500 + " lbs",
        "for field ops",
        "with remote monitoring",
        "recently serviced",
        "operator cabin with A/C",
        "all-weather capable",
        "low emissions certified"
    ))

    $rowsOut += [PSCustomObject]@{
        'Equipment Name'     = $equip.Name
        'Manufacturer'       = $manufacturer
        'Model'              = $model
        'Serial Number'      = $serial
        'Status'             = $status
        'Location'           = $location
        'Install Date'       = $installDate.ToString("MMMM d, yyyy")
        'Warranty Expiration'= $warrantyExpire.ToString("MMMM d, yyyy")
        'Description'        = $desc
    }
}

$rowsOut | Export-Csv -Path $Output -NoTypeInformation -Encoding UTF8

Write-Host "Generated $Rows rows of mock equipment data to $Output"
