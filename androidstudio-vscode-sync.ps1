Clear-Host

Write-Host "--------------------------------------------"
Write-Host "Android Studio → VS Code Sync Script"
Write-Host "--------------------------------------------"
Write-Host ""

$VSCodeOpened = $false
$checkInterval = 5
$delayBeforeOpen = 60

while ($true) {

    Write-Host "Checking if Android Studio is running..."

    # Fetch the process object so we can check the Window Title
    $asProcess = Get-Process | 
        Where-Object { $_.ProcessName -like "studio*" } | 
        Select-Object -First 1 -ErrorAction SilentlyContinue

    # 1. Check if Process exists
    if (-not $asProcess) {
        Write-Host "Android Studio NOT running"
        $VSCodeOpened = $false
        Start-Sleep $checkInterval
        continue
    }

    # 2. Security Check: Block if stuck on "Welcome" screen
    # This prevents opening the *previous* project while you are choosing a new one
    if ($asProcess.MainWindowTitle -match "Welcome to Android Studio") {
        Write-Host "Android Studio is at Project Selection (Welcome Screen). Waiting..."
        $VSCodeOpened = $false # Reset this so we can trigger again when a real project loads
        Start-Sleep $checkInterval
        continue
    }

    Write-Host "Android Studio detected (Project Loaded)"

    # Locate latest Android Studio config directory
    Write-Host "Locating latest Android Studio config directory..."

    $studioConfigDir = Get-ChildItem "$env:APPDATA\Google" `
        -Directory -Filter "AndroidStudio*" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $studioConfigDir) {
        Write-Host "No Android Studio config directory found"
        Start-Sleep $checkInterval
        continue
    }

    Write-Host "Using config directory:"
    Write-Host $studioConfigDir.FullName

    $recentProjectsFile = Join-Path $studioConfigDir.FullName "options\recentProjects.xml"

    if (-not (Test-Path $recentProjectsFile)) {
        Write-Host "recentProjects.xml not found"
        Start-Sleep $checkInterval
        continue
    }

    Write-Host "recentProjects.xml found at:"
    Write-Host $recentProjectsFile
    Write-Host "Reading last opened project..."

    try {
        [xml]$xml = Get-Content $recentProjectsFile

        $rawPath = $xml.application.component.option |
            Where-Object { $_.name -eq "lastOpenedProject" } |
            Select-Object -ExpandProperty value

        if (-not $rawPath) {
            Write-Host "No active project detected yet"
            Start-Sleep $checkInterval
            continue
        }

        Write-Host "Raw project path:"
        Write-Host $rawPath

        $projectPath = $rawPath -replace '\$USER_HOME\$', $env:USERPROFILE

        Write-Host "Resolved project path:"
        Write-Host $projectPath

        if ((Test-Path $projectPath) -and (-not $VSCodeOpened)) {

            Write-Host "Waiting $delayBeforeOpen seconds before opening VS Code..."
            
            $abortLaunch = $false

            # Smart Wait Loop: Checks status every second
            for ($i = $delayBeforeOpen; $i -gt 0; $i--) {
                
                # Re-check if Android Studio is still alive and not back at Welcome screen
                $currentProc = Get-Process | Where-Object { $_.ProcessName -like "studio*" } | Select-Object -First 1
                
                if (-not $currentProc) {
                    Write-Host "Android Studio closed during wait. Aborting launch."
                    $abortLaunch = $true
                    break
                }

                if ($currentProc.MainWindowTitle -match "Welcome to Android Studio") {
                    Write-Host "Returned to Welcome Screen during wait. Aborting launch."
                    $abortLaunch = $true
                    break
                }

                Write-Host "Opening VS Code in $i seconds..."
                Start-Sleep 1
            }

            if (-not $abortLaunch) {
                Write-Host "Opening VS Code now..."
                Start-Process "code" -ArgumentList "`"$projectPath`""
                $VSCodeOpened = $true
                Write-Host "VS Code opened successfully"
            } else {
                # If we aborted, ensure flag is false so we can try again later
                $VSCodeOpened = $false
            }
        }
        else {
            Write-Host "VS Code already opened or project path invalid"
        }
    }
    catch {
        Write-Host "Error reading recentProjects.xml"
        Write-Host $_
    }

    Start-Sleep $checkInterval
}