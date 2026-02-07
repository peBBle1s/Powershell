# Load Windows API for Low-Level Input
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class GameInput {
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);

    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);

    public const uint KEYEVENTF_SCANCODE = 0x0008;
    public const uint KEYEVENTF_KEYUP = 0x0002;
}
"@

# Configuration
$VK_MODIFIER = 0x11 # 0x11 is CTRL. (Use 0x5B for Windows Key if Ctrl conflicts)
$VK_MENU     = 0x12 # ALT Key
$VK_ESCAPE   = 0x1B # ESC Key to kill script
$SPACE_SCAN  = 0x39 # Physical Scan Code for Space bar

$running = $false
$lastState = $false
$random = New-Object System.Random

Write-Host "--- HAKAM'S PRO SPACE SPAMMER ---" -ForegroundColor Cyan
Write-Host "1. Run as Administrator: YES" -ForegroundColor Gray
Write-Host "2. Toggle Keys: [CTRL + ALT]" -ForegroundColor Yellow
Write-Host "3. Emergency Stop: [ESC]" -ForegroundColor Red
Write-Host "----------------------------------"
Write-Host "STATUS: IDLE" -NoNewline

try {
    while ($true) {
        # 1. Check for Emergency Exit (ESC)
        if ([GameInput]::GetAsyncKeyState($VK_ESCAPE) -band 0x8000) { break }

        # 2. Check for Toggle Combo
        $modDown = [GameInput]::GetAsyncKeyState($VK_MODIFIER) -band 0x8000
        $altDown = [GameInput]::GetAsyncKeyState($VK_MENU) -band 0x8000
        $currentlyPressed = $modDown -and $altDown

        # Trigger Toggle on Key Down (Rising Edge)
        if ($currentlyPressed -and -not $lastState) {
            $running = -not $running
            if ($running) {
                Write-Host "`rSTATUS: RUNNING (Spamming Space)   " -ForegroundColor Green -NoNewline
            } else {
                Write-Host "`rSTATUS: IDLE                      " -ForegroundColor Yellow -NoNewline
            }
            Start-Sleep -Milliseconds 400 # Prevents double-toggling
        }
        $lastState = $currentlyPressed

        # 3. Execution Logic
        if ($running) {
            # Press Space (Hardware Level)
            [GameInput]::keybd_event(0, $SPACE_SCAN, [GameInput]::KEYEVENTF_SCANCODE, 0)
            
            # Release Space (Hardware Level)
            [GameInput]::keybd_event(0, $SPACE_SCAN, [GameInput]::KEYEVENTF_SCANCODE -bor [GameInput]::KEYEVENTF_KEYUP, 0)
            
            # Randomized delay to mimic human behavior (30ms to 60ms)
            $sleepTime = $random.Next(30, 60)
            Start-Sleep -Milliseconds $sleepTime
        } else {
            # Low CPU usage when idle
            Start-Sleep -Milliseconds 100
        }
    }
}
finally {
    Write-Host "`n`n[!] Script Terminated Safely." -ForegroundColor White
}