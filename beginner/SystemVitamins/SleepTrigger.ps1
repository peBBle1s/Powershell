param (
    [Alias("h")] [switch]$Hibernate,
    [Alias("s")] [switch]$Sleep,
    [Alias("l")] [switch]$Lock,
    [Alias("sh")] [switch]$Shutdown,
    [int]$Interval = 60 
)

# Identify Action
$Action = $Hibernate ? "Hibernate" : ($Sleep ? "Sleep" : ($Lock ? "Lock" : ($Shutdown ? "Shutdown" : $null)))

if ($null -eq $Action) {
    Write-Host "Error: Argument required (-h, -s, -l, -sh)." -ForegroundColor Red
    exit
}

# --- ENHANCED LOGGING FUNCTION ---
function Write-Log {
    param([string]$Message, [string]$Color = "White", [bool]$TerminalOnly = $false)
    $DateStamp = Get-Date -Format "ddMMyyyy"
    $ExistingFile = Get-ChildItem -Path $PSScriptRoot -Filter "PowerAction_Log_$($DateStamp)_*.log" | Select-Object -First 1
    $CurrentLogPath = $ExistingFile ? $ExistingFile.FullName : (Join-Path $PSScriptRoot "PowerAction_Log_$($DateStamp)_$(Get-Date -Format 'HH_mm').log")
    
    if (-not $ExistingFile -and -not $TerminalOnly) { 
        "--- New Log Started: $(Get-Date) ---" | Out-File -FilePath $CurrentLogPath -Encoding utf8 
    }

    $FormattedMessage = ($Message.StartsWith("-") -or $Message -eq "") ? $Message : "[$(Get-Date -Format 'HH:mm:ss')] $Message"
    
    if ($Message -ne "") {
        Write-Host (" " * 60 + "`r") -NoNewline
        Write-Host $FormattedMessage -ForegroundColor $Color
    } else { Write-Host "" }

    if (-not $TerminalOnly) {
        $FormattedMessage | Out-File -FilePath $CurrentLogPath -Append -Encoding utf8
    }
}

Write-Log "MONITORING STARTED: Targeting [$Action]." "Cyan"

while ($true) {
    # 1. Gather Data
    $battery = Get-CimInstance -ClassName Win32_Battery
    $batteryPercent = $battery.EstimatedChargeRemaining
    $now = Get-Date
    
    try {
        $tempRaw = (Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue).CurrentTemperature
        $tempF = (($tempRaw / 10) - 273.15) * 9/5 + 32
        $cpuTempStr = "$([Math]::Round($tempF, 1))°F"
    } catch { $cpuTempStr = "N/A" }

    $braveYouTube = Get-Process brave -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like "*YouTube*" }
    
    # 2. Condition Logic (Strict Time & Logic Window)
    $hasYouTube = [bool]$braveYouTube
    
    # Check if time is between 1:30 AM and 6:00 AM
    $isAfterStart = ($now.Hour -eq 1 -and $now.Minute -ge 30) -or ($now.Hour -gt 1)
    $isBeforeEnd = ($now.Hour -lt 6)
    $isWithinTimeWindow = ($isAfterStart -and $isBeforeEnd)
    
    $isLowBattery = ($batteryPercent -lt 80)

    # --- LOG THE STATUS CHECK BLOCK TO FILE ---
    Write-Log "" -TerminalOnly $false
    Write-Log "--- Current Status Check ---" "Gray"
    Write-Log "YouTube Active:  $hasYouTube" ($hasYouTube ? "Green" : "Red")
    Write-Host "Time (>= 1:30AM): " -NoNewline; Write-Host "$isWithinTimeWindow ($($now.ToString('HH:mm')))" -ForegroundColor ($isWithinTimeWindow ? "Green" : "White")
    Write-Log "Battery (< 80%): $isLowBattery ($batteryPercent%)" ($isLowBattery ? "Green" : "White")
    Write-Log "CPU Temp:        $cpuTempStr" "Yellow"
    Write-Log "----------------------------" "Gray"

    # 3. Execution Logic: YouTube AND (Time OR Battery) AND (Before 6AM)
    if ($hasYouTube -and ($isWithinTimeWindow -or $isLowBattery) -and $isBeforeEnd) {
        Write-Log "MATCH FOUND! Executing $Action..." "Green"
        
        switch ($Action) {
            "Hibernate" { shutdown /h /f }
            "Sleep"     { Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Application]::SetSuspendState("Suspend", $false, $false) }
            "Lock"      { rundll32.exe user32.dll,LockWorkStation }
            "Shutdown"  { shutdown /s /t 0 /f }
        }
        break 
    }

    # 4. Countdown
    for ($i = $Interval; $i -gt 0; $i--) {
        Write-Host "Next check in: $($i)s | Monitoring... `r" -NoNewline -ForegroundColor Gray
        Start-Sleep -Seconds 1
    }
}