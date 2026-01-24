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

    $androidStudioRunning = Get-Process |
        Where-Object { $_.ProcessName -like "studio*" }

    if (-not $androidStudioRunning) {
        Write-Host "Android Studio NOT running"
        $VSCodeOpened = $false
        Start-Sleep $checkInterval
        continue
    }

    Write-Host "Android Studio detected"

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

            for ($i = $delayBeforeOpen; $i -gt 0; $i--) {
                Write-Host "Opening VS Code in $i seconds..."
                Start-Sleep 1
            }

            Write-Host "Opening VS Code now..."
            Start-Process "code" -ArgumentList "`"$projectPath`""

            $VSCodeOpened = $true
            Write-Host "VS Code opened successfully"
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
