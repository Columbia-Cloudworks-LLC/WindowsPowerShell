<#
.SYNOPSIS
 Retrieves Windows Server Backup status from all Domain Controllers WITHOUT using WinRM/PSRemoting.

.DESCRIPTION
 For each DC in the domain, this script:
   1) Checks if the "wbengine" service exists (indicating Windows Server Backup is installed).
   2) Reads that service's current Status (Running, Stopped, etc.).
   3) Queries the remote Application event log for the latest EventID 4 from "Microsoft-Windows-Backup" (i.e. last successful backup time).

 USAGE
   • Run as a user with:
       - ActiveDirectory module installed locally
       - RPC/DCOM access (remote service & EventLog permissions) to each DC
   • Enable script execution if needed (e.g. `Set-ExecutionPolicy RemoteSigned -Scope Process`).

.EXAMPLE
   PS> .\Get-WSBStatus-NoRemoting.ps1
#>

#----------------------------------------
# 1) Import AD module so we can list DCs
#----------------------------------------
Try {
    Import-Module ActiveDirectory -ErrorAction Stop
}
Catch {
    Write-Error "ActiveDirectory module not found or failed to load. Install RSAT/AD DS Tools first."
    Exit 1
}

#-------------------------------------------------
# 2) Get all Domain Controller hostnames in the AD
#-------------------------------------------------
$dcList = Get-ADDomainController -Filter * | Select-Object -ExpandProperty HostName

If (-not $dcList) {
    Write-Warning "No domain controllers found (Are you joined to a domain?)."
    Exit 1
}

#--------------------------------------
# 3) Iterate each DC and collect details
#--------------------------------------
$results = foreach ($dc in $dcList) {
    # Prepare defaults in case of errors
    $wsbInstalled   = $false
    $serviceStatus  = 'Unknown'
    $lastBackupTime = 'Unknown'

    # Wrap in try/catch to handle RPC failures, offline DCs, etc.
    Try {
        # ----------------------------
        # 3a) Check wbengine service
        # ----------------------------
        $svc = Get-Service -Name 'wbengine' -ComputerName $dc -ErrorAction Stop

        # If no exception, service exists
        $wsbInstalled  = $true
        $serviceStatus = $svc.Status

        # -----------------------------------
        # 3b) Query last Backup Event (ID 4)
        # -----------------------------------
        # We specifically look for EventID 4 from the "Microsoft-Windows-Backup" provider,
        # which corresponds to "Backup successfully completed" (on most modern servers).
        Try {
            $evt = Get-WinEvent -FilterHashtable @{
                        LogName       = 'Application'
                        ProviderName  = 'Microsoft-Windows-Backup'
                        Id            = 4
                    } -MaxEvents 1 -ComputerName $dc -ErrorAction Stop

            If ($evt) {
                $lastBackupTime = $evt.TimeCreated
            }
            Else {
                $lastBackupTime = 'NoBackupEventFound'
            }
        }
        Catch {
            # Could be "no such source" or lack of permissions
            $lastBackupTime = 'ErrorReadingBackupEvents'
        }
    }
    Catch {
        # If Get-Service fails (service missing or RPC issue), treat as not installed or unreachable
        If ($_.Exception -and $_.Exception.Message -match 'Cannot find any service with service name') {
            $wsbInstalled   = $false
            $serviceStatus  = 'NotInstalled'
            $lastBackupTime = 'WSBNotInstalled'
        }
        Else {
            # Some RPC/DCOM error or offline DC
            $wsbInstalled   = $false
            $serviceStatus  = 'RPC/AccessError'
            $lastBackupTime = $_.Exception.Message
        }
    }

    # Return a PSCustomObject for this DC
    [PSCustomObject]@{
        ComputerName    = $dc
        WSBInstalled    = $wsbInstalled
        ServiceStatus   = $serviceStatus
        LastBackupTime  = $lastBackupTime
    }
}

#---------------------------------------
# 4) Display the results in a nice table
#---------------------------------------
$results |
    Sort-Object ComputerName |
    Format-Table –AutoSize
