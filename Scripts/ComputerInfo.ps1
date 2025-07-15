# Get Hostname
$hostname = $env:COMPUTERNAME

# Get IPv4 Address, Subnet Address, and Default Gateway
$network = Get-NetIPConfiguration | Where-Object { $_.IPv4Address -ne $null }
$ipv4Address = $network.IPv4Address.IPAddress
$subnetAddress = $network.IPv4Address.PrefixLength
$defaultGateway = $network.IPv4DefaultGateway.NextHop

# Check if IPv6 is Enabled
$ipv6Enabled = ($null -ne $network.IPv6Address)

# Get CPU Information
$cpu = Get-CimInstance -ClassName Win32_Processor
$cpuManufacturer = $cpu.Manufacturer
$cpuModel = $cpu.Name
$cpuMaxClockSpeed = $cpu.MaxClockSpeed
$cpuCores = $cpu.NumberOfCores
$cpuThreads = $cpu.NumberOfLogicalProcessors

# Get Memory Information
$memory = Get-CimInstance -ClassName Win32_PhysicalMemory
$totalMemory = [math]::round(($memory.Capacity | Measure-Object -Sum).Sum / 1GB, 2)

# Get Operating System Information
$os = Get-CimInstance -ClassName Win32_OperatingSystem
$osName = $os.Caption

# Get Drive Information
$drives = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3"
$driveInfo = $drives | ForEach-Object { "$($_.DeviceID) ($([math]::round($_.Size / 1GB, 2)) GB)" }

# Display Information
Write-Output "Hostname: $hostname"
Write-Output "IPv4 Address: $ipv4Address"
Write-Output "Subnet Address: $subnetAddress"
Write-Output "Default Gateway: $defaultGateway"
Write-Output "IPv6 Enabled: $ipv6Enabled"
Write-Output "CPU Manufacturer: $cpuManufacturer"
Write-Output "CPU Model: $cpuModel"
Write-Output "CPU Max Clock Speed: $cpuMaxClockSpeed MHz"
Write-Output "CPU Cores: $cpuCores"
Write-Output "CPU Threads: $cpuThreads"
Write-Output "Memory: $totalMemory GB"
Write-Output "Operating System: $osName"
Write-Output "Drive Info: $($driveInfo -join '; ')"
