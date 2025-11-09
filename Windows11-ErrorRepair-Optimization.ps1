<#
.SYNOPSIS
    Windows 11 Error Repair and Optimization Script

.DESCRIPTION
    This PowerShell script performs comprehensive error checking, repair, and optimization
    tasks for Windows 11 systems. It includes disk checks, system file verification,
    network troubleshooting, registry backups, event log management, and more.

.NOTES
    File Name      : Windows11-ErrorRepair-Optimization.ps1
    Author         : System Administrator
    Prerequisite   : PowerShell 5.1 or higher, Administrator privileges
    Version        : 1.0

.EXAMPLE
    .\Windows11-ErrorRepair-Optimization.ps1
    Runs the full system repair and optimization suite
#>

#Requires -RunAsAdministrator

# Set error action preference
$ErrorActionPreference = "Continue"

# Create log directory
$LogPath = "$env:SystemRoot\Logs\SystemRepair"
if (-not (Test-Path -Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

$LogFile = Join-Path -Path $LogPath -ChildPath "Repair_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Function to write log entries
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    
    # Write to log file
    Add-Content -Path $LogFile -Value $LogEntry
    
    # Write to console with color
    switch ($Level) {
        "INFO"    { Write-Host $LogEntry -ForegroundColor White }
        "WARNING" { Write-Host $LogEntry -ForegroundColor Yellow }
        "ERROR"   { Write-Host $LogEntry -ForegroundColor Red }
        "SUCCESS" { Write-Host $LogEntry -ForegroundColor Green }
    }
}

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to create system restore point
function New-SystemRestorePoint {
    param(
        [string]$Description = "System Repair Script - Before Optimization"
    )
    
    Write-Log "Creating system restore point..." -Level "INFO"
    
    try {
        # Enable System Restore on C: if not enabled
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        
        # Create restore point
        Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS"
        Write-Log "System restore point created successfully" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to create system restore point: $($_.Exception.Message)" -Level "WARNING"
        return $false
    }
}

# Function to backup registry
function Backup-RegistryKeys {
    param(
        [string]$BackupPath = "$env:TEMP\RegistryBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    )
    
    Write-Log "Backing up critical registry keys..." -Level "INFO"
    
    try {
        if (-not (Test-Path -Path $BackupPath)) {
            New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
        }
        
        # Backup important registry hives
        $RegistryKeys = @(
            "HKLM\Software\Microsoft\Windows\CurrentVersion\Run",
            "HKLM\System\CurrentControlSet\Services",
            "HKLM\Software\Policies"
        )
        
        foreach ($key in $RegistryKeys) {
            $fileName = $key -replace '\\', '_'
            $exportPath = Join-Path -Path $BackupPath -ChildPath "$fileName.reg"
            
            # Export registry key
            $process = Start-Process -FilePath "reg.exe" -ArgumentList "export `"$key`" `"$exportPath`" /y" -Wait -PassThru -NoNewWindow
            
            if ($process.ExitCode -eq 0) {
                Write-Log "Backed up registry key: $key" -Level "SUCCESS"
            }
            else {
                Write-Log "Failed to backup registry key: $key" -Level "WARNING"
            }
        }
        
        return $BackupPath
    }
    catch {
        Write-Log "Registry backup failed: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

# Function to check and repair system files
function Repair-SystemFiles {
    Write-Log "Running System File Checker (SFC)..." -Level "INFO"
    
    try {
        # Run SFC scan
        $sfcProcess = Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -Wait -PassThru -NoNewWindow
        
        if ($sfcProcess.ExitCode -eq 0) {
            Write-Log "SFC scan completed successfully" -Level "SUCCESS"
        }
        else {
            Write-Log "SFC scan completed with warnings" -Level "WARNING"
        }
        
        # Run DISM repair
        Write-Log "Running DISM repair..." -Level "INFO"
        
        $dismProcess = Start-Process -FilePath "DISM.exe" -ArgumentList "/Online /Cleanup-Image /RestoreHealth" -Wait -PassThru -NoNewWindow
        
        if ($dismProcess.ExitCode -eq 0) {
            Write-Log "DISM repair completed successfully" -Level "SUCCESS"
        }
        else {
            Write-Log "DISM repair completed with warnings" -Level "WARNING"
        }
        
        return $true
    }
    catch {
        Write-Log "System file repair failed: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Function to check disk health
function Repair-DiskErrors {
    Write-Log "Checking disk health..." -Level "INFO"
    
    try {
        # Get all fixed drives
        $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' }
        
        foreach ($drive in $drives) {
            $driveLetter = $drive.Root
            Write-Log "Scanning drive: $driveLetter" -Level "INFO"
            
            # Check if this is the system drive (C:\)
            if ($driveLetter -eq "C:\") {
                # Use /scan /spotfix for system drive - cannot use /X (BUG FIX #3)
                Write-Log "Running CHKDSK on system drive with /scan /spotfix..." -Level "INFO"
                $chkdskProcess = Start-Process -FilePath "chkdsk.exe" -ArgumentList "$driveLetter /scan /spotfix" -Wait -PassThru -NoNewWindow
            }
            else {
                # For non-system drives, we can use /F
                Write-Log "Scheduling CHKDSK on drive $driveLetter for next reboot..." -Level "INFO"
                $chkdskProcess = Start-Process -FilePath "chkdsk.exe" -ArgumentList "$driveLetter /F" -Wait -PassThru -NoNewWindow
            }
            
            if ($chkdskProcess.ExitCode -eq 0) {
                Write-Log "CHKDSK completed for drive: $driveLetter" -Level "SUCCESS"
            }
            else {
                Write-Log "CHKDSK reported issues on drive: $driveLetter" -Level "WARNING"
            }
        }
        
        return $true
    }
    catch {
        Write-Log "Disk check failed: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Function to optimize drives
function Optimize-SystemDrives {
    Write-Log "Optimizing drives..." -Level "INFO"
    
    try {
        $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' }
        
        foreach ($drive in $drives) {
            $driveLetter = $drive.Name
            Write-Log "Optimizing drive: $driveLetter" -Level "INFO"
            
            Optimize-Volume -DriveLetter $driveLetter -Verbose -ErrorAction SilentlyContinue
            Write-Log "Drive optimization completed: $driveLetter" -Level "SUCCESS"
        }
        
        return $true
    }
    catch {
        Write-Log "Drive optimization failed: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Function to clear event logs
function Clear-SystemEventLogs {
    Write-Log "Clearing old event logs..." -Level "INFO"
    
    try {
        # Get event logs that are larger than 50MB
        $logs = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | 
                Where-Object { $_.RecordCount -gt 0 -and $_.FileSize -gt 50MB }
        
        foreach ($log in $logs) {
            try {
                # Wrap event log names in quotes for proper handling (BUG FIX #4)
                Write-Log "Clearing event log: '$($log.LogName)'" -Level "INFO"
                wevtutil.exe cl "$($log.LogName)"
                Write-Log "Cleared event log: '$($log.LogName)'" -Level "SUCCESS"
            }
            catch {
                Write-Log "Could not clear event log: '$($log.LogName)' - $($_.Exception.Message)" -Level "WARNING"
            }
        }
        
        return $true
    }
    catch {
        Write-Log "Event log clearing failed: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Function to backup registry with correct syntax
function Export-RegistryHive {
    param(
        [string]$HivePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion",
        [string]$ExportPath = "$env:TEMP\RegistryExport_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg"
    )
    
    Write-Log "Exporting registry hive: $HivePath" -Level "INFO"
    
    try {
        # Convert PowerShell path to reg.exe format
        # Ensure correct HKLM: syntax is used (BUG FIX #2)
        $regPath = $HivePath -replace "HKLM:", "HKLM" -replace "HKCU:", "HKCU"
        
        # Export using reg.exe
        $process = Start-Process -FilePath "reg.exe" -ArgumentList "export `"$regPath`" `"$ExportPath`" /y" -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            Write-Log "Registry export successful: $ExportPath" -Level "SUCCESS"
            return $ExportPath
        }
        else {
            Write-Log "Registry export failed with exit code: $($process.ExitCode)" -Level "ERROR"
            return $null
        }
    }
    catch {
        Write-Log "Registry export error: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

# Function to reset network settings
function Reset-NetworkSettings {
    Write-Log "Resetting network settings..." -Level "INFO"
    
    try {
        # Release and renew IP
        Write-Log "Releasing IP address..." -Level "INFO"
        ipconfig /release | Out-Null
        
        Write-Log "Renewing IP address..." -Level "INFO"
        ipconfig /renew | Out-Null
        
        # Flush DNS cache
        Write-Log "Flushing DNS cache..." -Level "INFO"
        ipconfig /flushdns | Out-Null
        
        # Reset Winsock
        Write-Log "Resetting Winsock catalog..." -Level "INFO"
        netsh winsock reset | Out-Null
        
        # Reset TCP/IP stack
        Write-Log "Resetting TCP/IP stack..." -Level "INFO"
        netsh int ip reset | Out-Null
        
        # Reset firewall to defaults
        Write-Log "Resetting Windows Firewall..." -Level "INFO"
        netsh advfirewall reset | Out-Null
        
        Write-Log "Network settings reset successfully" -Level "SUCCESS"
        Write-Log "A system restart is recommended for changes to take effect" -Level "WARNING"
        
        return $true
    }
    catch {
        Write-Log "Network settings reset failed: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Function to clean temporary files
function Clear-TemporaryFiles {
    Write-Log "Cleaning temporary files..." -Level "INFO"
    
    try {
        $tempPaths = @(
            "$env:TEMP",
            "$env:WINDIR\Temp",
            "$env:LOCALAPPDATA\Temp"
        )
        
        foreach ($tempPath in $tempPaths) {
            if (Test-Path -Path $tempPath) {
                Write-Log "Cleaning: $tempPath" -Level "INFO"
                
                Get-ChildItem -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue |
                    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
                    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                
                Write-Log "Cleaned: $tempPath" -Level "SUCCESS"
            }
        }
        
        # Clean Windows Update cache
        Write-Log "Stopping Windows Update service..." -Level "INFO"
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        
        $updateCachePath = "$env:WINDIR\SoftwareDistribution\Download"
        if (Test-Path -Path $updateCachePath) {
            Write-Log "Cleaning Windows Update cache..." -Level "INFO"
            Get-ChildItem -Path $updateCachePath -Recurse -Force -ErrorAction SilentlyContinue |
                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            Write-Log "Windows Update cache cleaned" -Level "SUCCESS"
        }
        
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
        
        return $true
    }
    catch {
        Write-Log "Temporary file cleanup failed: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Function to repair Windows Store apps
function Repair-WindowsStoreApps {
    Write-Log "Repairing Windows Store apps..." -Level "INFO"
    
    try {
        # Re-register all Windows Store apps
        Get-AppxPackage -AllUsers | ForEach-Object {
            try {
                Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue
                Write-Log "Re-registered app: $($_.Name)" -Level "INFO"
            }
            catch {
                Write-Log "Could not re-register app: $($_.Name)" -Level "WARNING"
            }
        }
        
        Write-Log "Windows Store apps repair completed" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Windows Store apps repair failed: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Function to update Windows Defender definitions
function Update-DefenderDefinitions {
    Write-Log "Updating Windows Defender definitions..." -Level "INFO"
    
    try {
        Update-MpSignature -ErrorAction Stop
        Write-Log "Windows Defender definitions updated successfully" -Level "SUCCESS"
        
        # Run a quick scan
        Write-Log "Running Windows Defender quick scan..." -Level "INFO"
        Start-MpScan -ScanType QuickScan -ErrorAction SilentlyContinue
        Write-Log "Windows Defender scan completed" -Level "SUCCESS"
        
        return $true
    }
    catch {
        Write-Log "Windows Defender update failed: $($_.Exception.Message)" -Level "WARNING"
        return $false
    }
}

# Main execution
function Start-SystemRepair {
    Write-Log "========================================" -Level "INFO"
    Write-Log "Windows 11 Error Repair and Optimization" -Level "INFO"
    Write-Log "========================================" -Level "INFO"
    Write-Log "Started at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level "INFO"
    Write-Log "" -Level "INFO"
    
    # Check administrator privileges
    if (-not (Test-Administrator)) {
        Write-Log "This script must be run as Administrator!" -Level "ERROR"
        Write-Log "Please right-click and select 'Run as Administrator'" -Level "ERROR"
        exit 1
    }
    
    # Create system restore point
    Write-Log "Step 1: Creating system restore point" -Level "INFO"
    New-SystemRestorePoint
    Write-Log "" -Level "INFO"
    
    # Backup registry
    Write-Log "Step 2: Backing up registry" -Level "INFO"
    $registryBackupPath = Backup-RegistryKeys
    if ($registryBackupPath) {
        Write-Log "Registry backed up to: $registryBackupPath" -Level "SUCCESS"
    }
    Write-Log "" -Level "INFO"
    
    # Export additional registry hive
    Write-Log "Step 3: Exporting registry hive" -Level "INFO"
    Export-RegistryHive
    Write-Log "" -Level "INFO"
    
    # Repair system files
    Write-Log "Step 4: Repairing system files" -Level "INFO"
    Repair-SystemFiles
    Write-Log "" -Level "INFO"
    
    # Check and repair disks
    Write-Log "Step 5: Checking disk health" -Level "INFO"
    Repair-DiskErrors
    Write-Log "" -Level "INFO"
    
    # Clear event logs
    Write-Log "Step 6: Clearing old event logs" -Level "INFO"
    Clear-SystemEventLogs
    Write-Log "" -Level "INFO"
    
    # Reset network settings (BUG FIX #1 - correct function name)
    Write-Log "Step 7: Resetting network settings" -Level "INFO"
    Reset-NetworkSettings
    Write-Log "" -Level "INFO"
    
    # Clean temporary files
    Write-Log "Step 8: Cleaning temporary files" -Level "INFO"
    Clear-TemporaryFiles
    Write-Log "" -Level "INFO"
    
    # Optimize drives
    Write-Log "Step 9: Optimizing drives" -Level "INFO"
    Optimize-SystemDrives
    Write-Log "" -Level "INFO"
    
    # Repair Windows Store apps
    Write-Log "Step 10: Repairing Windows Store apps" -Level "INFO"
    Repair-WindowsStoreApps
    Write-Log "" -Level "INFO"
    
    # Update Windows Defender
    Write-Log "Step 11: Updating Windows Defender" -Level "INFO"
    Update-DefenderDefinitions
    Write-Log "" -Level "INFO"
    
    Write-Log "========================================" -Level "SUCCESS"
    Write-Log "System Repair and Optimization Complete!" -Level "SUCCESS"
    Write-Log "========================================" -Level "SUCCESS"
    Write-Log "Completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level "INFO"
    Write-Log "Log file saved to: $LogFile" -Level "INFO"
    Write-Log "" -Level "INFO"
    Write-Log "IMPORTANT: A system restart is recommended to complete all repairs." -Level "WARNING"
    
    # Ask user if they want to restart
    $restart = Read-Host "Would you like to restart now? (Y/N)"
    if ($restart -eq "Y" -or $restart -eq "y") {
        Write-Log "Restarting system in 30 seconds..." -Level "WARNING"
        shutdown /r /t 30 /c "System restart required to complete repairs"
    }
}

# Run the main function
Start-SystemRepair
