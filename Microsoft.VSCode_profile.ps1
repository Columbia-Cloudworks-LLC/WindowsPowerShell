# Functions
function Starkill {
    $processName = "starfield.exe"
    $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
    if ($processes) {
        $processes | Stop-Process -Force
        Write-Host "Killed all processes named $processName." -ForegroundColor Green
    } else {
        Write-Host "No process named $processName was found." -ForegroundColor Yellow
    }
}

# Aliases
Set-Alias -Name starkill -Value Starkill
