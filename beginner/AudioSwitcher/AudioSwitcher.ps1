#!/usr/bin/env pwsh
# Audio Output Switcher - PowerShell 7 Edition

function Ensure-Dependencies {
    # Check if the module is imported or available
    if (-not (Get-Module -ListAvailable -Name AudioDeviceCmdlets)) {
        Write-Host "⚠️  Required module 'AudioDeviceCmdlets' not found." -ForegroundColor Yellow
        $confirm = Read-Host "Do you want to install it now? (y/n)"
        if ($confirm -eq 'y') {
            Write-Host "Installing module... (This may require Admin rights)" -ForegroundColor Cyan
            Install-Module -Name AudioDeviceCmdlets -Force -Scope CurrentUser -AllowClobber
            Import-Module AudioDeviceCmdlets
        } else {
            Write-Host "❌ Script cannot run without this module. Exiting." -ForegroundColor Red
            exit
        }
    } else {
        # Import if not already active
        if (-not (Get-Module -Name AudioDeviceCmdlets)) {
            Import-Module AudioDeviceCmdlets
        }
    }
}

function Show-Header {
    Clear-Host
    Write-Host "`n   🔊  AUDIO COMMAND CENTER  " -BackgroundColor DarkCyan -ForegroundColor White
    Write-Host "   ------------------------" -ForegroundColor DarkCyan
}

function Select-AudioSource {
    Show-Header
    Write-Host "`nScanning devices..." -ForegroundColor Gray

    # Get playback devices
    $devices = Get-AudioDevice -List | Where-Object Type -eq 'Playback'
    
    if (-not $devices) {
        Write-Host "❌ No playback devices found." -ForegroundColor Red
        Start-Sleep -Seconds 2
        return
    }

    # Display list nicely
    Write-Host "`nAvailable Output Devices:" -ForegroundColor Cyan
    
    for ($i = 0; $i -lt $devices.Count; $i++) {
        $dev = $devices[$i]
        $marker = "  "
        $color = "White"

        # Highlight current default device
        if ($dev.Default) {
            $marker = "➤ "
            $color = "Green"
        }

        Write-Host "$($i+1). $marker$($dev.Name)" -ForegroundColor $color
    }

    Write-Host ""
    $selection = Read-Host "Enter number to switch (or 'b' to go back)"

    if ($selection -eq 'b') { return }

    # Validate input (PS7 smart checking)
    if ($selection -match '^\d+$' -and $selection -gt 0 -and $selection -le $devices.Count) {
        $target = $devices[$selection - 1]
        
        # Set the device
        Set-AudioDevice -Index $target.Index | Out-Null
        
        Write-Host "`n✅ Switched to: $($target.Name)" -ForegroundColor Green
        
        # Play a sound to confirm (Optional)
        [System.Console]::Beep(440, 200)
    } else {
        Write-Host "❌ Invalid selection." -ForegroundColor Red
    }
    
    Start-Sleep -Seconds 2
}

# --- Main Execution ---

Ensure-Dependencies

$running = $true

while ($running) {
    Show-Header
    
    Write-Host "`n1. 🎧 Select Audio Out Source"
    Write-Host "2. 🚧 [Future Feature]"
    Write-Host "3. 🚫 No Action"
    Write-Host "4. 🚪 Exit"
    Write-Host ""

    $choice = Read-Host "Choose an option"

    switch ($choice) {
        '1' { Select-AudioSource }
        '2' { 
            Write-Host "`n   This feature is not yet decided." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
        '3' { 
            Write-Host "`n   ... (Silence) ..." -ForegroundColor Gray
            Start-Sleep -Seconds 1 
        }
        { $_ -in '4','q','exit' } { 
            Write-Host "`nGoodbye! 👋" -ForegroundColor Cyan
            $running = $false 
        }
        Default { 
            Write-Host "   Invalid input." -ForegroundColor Red 
            Start-Sleep -Milliseconds 500
        }
    }
}