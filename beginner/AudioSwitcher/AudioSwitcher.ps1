#!/usr/bin/env pwsh
# ============================================================
# 🎚️ AUDIO COMMAND CENTER (Fixed & Stable)
# ============================================================

# -------------------- AUTO ELEVATE --------------------
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    Write-Host "Restarting as Administrator..." -ForegroundColor Yellow
    Start-Process pwsh -Verb RunAs -ArgumentList "-File `"$PSCommandPath`""
    exit
}

# -------------------- CONFIG --------------------
$NirSoftUrl = "https://www.nirsoft.net/utils/soundvolumeview-x64.zip"
$ToolPath   = Join-Path $PSScriptRoot "SoundVolumeView.exe"

# -------------------- DEPENDENCIES --------------------
function Ensure-Dependencies {

    # AudioDeviceCmdlets
    if (-not (Get-Module -ListAvailable -Name AudioDeviceCmdlets)) {
        Write-Host "Installing AudioDeviceCmdlets..." -ForegroundColor Yellow
        Install-Module -Name AudioDeviceCmdlets -Force -Scope CurrentUser -AllowClobber
    }
    Import-Module AudioDeviceCmdlets

    # SoundVolumeView
    if (-not (Test-Path $ToolPath)) {
        Write-Host "Downloading SoundVolumeView..." -ForegroundColor Cyan
        $zipPath = Join-Path $PSScriptRoot "svv.zip"

        try {
            Invoke-WebRequest -Uri $NirSoftUrl -OutFile $zipPath
            Expand-Archive -Path $zipPath -DestinationPath $PSScriptRoot -Force
            Remove-Item $zipPath -Force
        } catch {
            Write-Host "Failed to download SoundVolumeView." -ForegroundColor Red
            exit
        }
    }
}

# -------------------- HEADER --------------------
function Show-Header {
    Clear-Host
    Write-Host "`n   🔊 AUDIO COMMAND CENTER" -BackgroundColor DarkCyan -ForegroundColor White
    Write-Host "   ------------------------" -ForegroundColor DarkCyan

    try {
        $dev = Get-AudioDevice -Playback
        $mute = if ($dev.Mute) { "MUTED" } else { "ON" }
        Write-Host "   Default: $($dev.Name)"
        Write-Host "   Volume:  $($dev.Volume)% [$mute]"
    } catch {
        Write-Host "   No active playback device detected"
    }

    Write-Host "   ------------------------`n" -ForegroundColor DarkCyan
}

# -------------------- GLOBAL SWITCH --------------------
function Select-GlobalDevice {

    $devices = Get-AudioDevice -List | Where-Object Type -eq 'Playback'
    if (-not $devices) { return }

    Write-Host "Select GLOBAL Output Device:`n"

    for ($i=0; $i -lt $devices.Count; $i++) {
        $marker = if ($devices[$i].Default) { "➤" } else { " " }
        Write-Host "$($i+1). $marker $($devices[$i].Name)"
    }

    $sel = Read-Host "`nEnter number"
    if ($sel -match '^\d+$' -and $sel -le $devices.Count) {
        Set-AudioDevice -Index $devices[$sel-1].Index
        Write-Host "Switched successfully." -ForegroundColor Green
        Start-Sleep 1
    }
}

# -------------------- PER APP ROUTING (FIXED) --------------------
function Set-AppRouting {

    Write-Host "Scanning active audio apps..." -ForegroundColor Yellow
    $csvFile = Join-Path $PSScriptRoot "apps.csv"

    if (Test-Path $csvFile) { Remove-Item $csvFile -Force }

    # Export current audio sessions
    Start-Process -FilePath $ToolPath -ArgumentList "/scomma `"$csvFile`"" -Wait -NoNewWindow

    if (-not (Test-Path $csvFile)) {
        Write-Host "Scan failed." -ForegroundColor Red
        return
    }

    $allData = Import-Csv $csvFile

    $apps = $allData | Where-Object {
        $_.Type -eq "Application" -and $_."Process Path"
    } | Select-Object -Unique Name, "Process Path"

    if (-not $apps) {
        Write-Host "No active audio apps found. Play audio first." -ForegroundColor Red
        Start-Sleep 2
        return
    }

    Write-Host "`nActive Apps:`n"
    for ($i=0; $i -lt $apps.Count; $i++) {
        Write-Host "$($i+1). $($apps[$i].Name)"
    }

    $appSel = Read-Host "`nSelect app number"
    if ($appSel -notmatch '^\d+$' -or $appSel -gt $apps.Count) { return }

    $appExe = Split-Path $apps[$appSel-1]."Process Path" -Leaf

    # Device selection
    $devices = Get-AudioDevice -List | Where-Object Type -eq 'Playback'

    Write-Host "`nSelect Target Device:`n"
    for ($i=0; $i -lt $devices.Count; $i++) {
        Write-Host "$($i+1). $($devices[$i].Name)"
    }

    $devSel = Read-Host "`nSelect device number"
    if ($devSel -notmatch '^\d+$' -or $devSel -gt $devices.Count) { return }

    $targetDev = $devices[$devSel-1]

    Write-Host "`nApplying routing to $appExe ..." -ForegroundColor Cyan

    $roles = @(0,1,2)

    foreach ($role in $roles) {
        Start-Process -FilePath $ToolPath `
            -ArgumentList "/SetAppDefault `"$($targetDev.ID)`" $role `"$appExe`"" `
            -Wait -NoNewWindow
    }

    Write-Host "Route applied." -ForegroundColor Green
    Write-Host "IMPORTANT: Pause and resume audio in the app." -ForegroundColor Yellow
    Start-Sleep 2
}

# -------------------- MAIN --------------------
Ensure-Dependencies

while ($true) {

    Show-Header

    Write-Host "1. Global Output Switcher"
    Write-Host "2. Per-App Audio Routing"
    Write-Host "3. Set Master Volume"
    Write-Host "4. Toggle Mute"
    Write-Host "5. Open Windows Audio Settings"
    Write-Host "Q. Quit"
    Write-Host ""

    $choice = Read-Host "Select option"

    switch ($choice) {

        '1' { Select-GlobalDevice }
        '2' { Set-AppRouting }
        '3' {
            $v = Read-Host "Enter Volume (0-100)"
            if ($v -match '^\d+$' -and $v -le 100) {
                Set-AudioDevice -PlaybackVolume $v
            }
        }
        '4' {
            $dev = Get-AudioDevice -Playback
            Set-AudioDevice -PlaybackMute (-not $dev.Mute)
        }
        '5' {
            Start-Process "ms-settings:apps-volume"
        }
        { $_ -in 'q','quit','exit' } {
            exit
        }
    }
}
