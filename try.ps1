Clear-Host

Write-Host "--------------------------------------------"
Write-Host "Android Studio -> VS Code Sync Script"
Write-Host "--------------------------------------------"
Write-Host "Mode: XML Option Tag Parsing (Fixing Time: 0)"
Write-Host ""

$VSCodeOpened = $false
$checkInterval = 5
$delayBeforeOpen = 60
$lastDetectedPath = ""

# Helper: Convert Unix Milliseconds to Readable Date
function Convert-MsToDate($ms) {
    if (-not $ms -or $ms -eq 0) { return "N/A" }
    $seconds = [math]::Floor($ms / 1000)
    return (Get-Date "1970-01-01 00:00:00Z").AddSeconds($seconds).ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss")
}

while ($true) {

    Write-Host "Checking if Android Studio is running..."

    # 1. Check Process & Window Title
    $asProcess = Get-Process | 
        Where-Object { $_.ProcessName -like "studio*" } | 
        Select-Object -First 1 -ErrorAction SilentlyContinue

    if (-not $asProcess) {
        Write-Host "Android Studio NOT running"
        $VSCodeOpened = $false
        $lastDetectedPath = ""
        Start-Sleep $checkInterval
        continue
    }

    $windowTitle = $asProcess.MainWindowTitle

    # 2. Gatekeeper: Welcome Screen
    if ($windowTitle -match "Welcome to Android Studio") {
        Write-Host "Status: Welcome Screen (No project loaded)"
        $VSCodeOpened = $false
        $lastDetectedPath = ""
        Start-Sleep $checkInterval
        continue
    }

    Write-Host "Android Studio detected. Reading History..."

    # 3. Find Config Directory
    $studioConfigDir = Get-ChildItem "$env:APPDATA\Google" `
        -Directory -Filter "AndroidStudio*" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $studioConfigDir) {
        Write-Host "Config directory not found."
        Start-Sleep $checkInterval
        continue
    }

    $recentProjectsFile = Join-Path $studioConfigDir.FullName "options\recentProjects.xml"

    if (-not (Test-Path $recentProjectsFile)) {
        Write-Host "recentProjects.xml not found."
        Start-Sleep $checkInterval
        continue
    }

    try {
        [xml]$xml = Get-Content $recentProjectsFile

        # 4. Parse History Map
        $component = $xml.application.component | Where-Object { $_.name -eq "RecentProjectsManager" }
        $mapOption = $component.option | Where-Object { $_.name -eq "additionalInfo" }
        
        if (-not $mapOption) {
            Write-Host "History map not found in XML."
            Start-Sleep $checkInterval
            continue
        }

        $entries = $mapOption.map.entry
        $projectCandidates = @()

        foreach ($entry in $entries) {
            $rawKey = $entry.key
            $resolvedPath = $rawKey -replace '\$USER_HOME\$', $env:USERPROFILE
            
            # --- XML PARSING FIX ---
            # Timestamps are inside <option> tags, not direct properties.
            $metaInfo = $entry.value.RecentProjectMetaInfo
            $optionsList = $metaInfo.option 

            $ts = 0
            
            # 1. Try to find 'activationTimestamp' (Usually the most accurate for "Last Used")
            $activationOpt = $optionsList | Where-Object { $_.name -eq "activationTimestamp" }
            if ($activationOpt) { 
                $ts = [int64]$activationOpt.value 
            } 
            
            # 2. If not found (or 0), use 'projectOpenTimestamp' as you requested
            if ($ts -eq 0) {
                $openOpt = $optionsList | Where-Object { $_.name -eq "projectOpenTimestamp" }
                if ($openOpt) { 
                    $ts = [int64]$openOpt.value 
                }
            }
            # -----------------------

            $projName = Split-Path $resolvedPath -Leaf

            $projectCandidates += [PSCustomObject]@{
                RawPath = $rawKey
                Path = $resolvedPath
                Name = $projName
                Timestamp = [long]$ts
                ReadableTime = Convert-MsToDate $ts
            }
        }

        # 5. SORT BY TIMESTAMP DESCENDING
        $sortedProjects = $projectCandidates | Sort-Object Timestamp -Descending

        $targetProject = $null

        # 6. Step-Back Logic
        Write-Host "Window Title: '$windowTitle'"
        Write-Host "Scanning History (Order: Newest -> Oldest):"
        
        $rank = 1
        foreach ($proj in $sortedProjects) {
            $safeName = [Regex]::Escape($proj.Name)
            
            Write-Host "  [$rank] Name: $($proj.Name)"
            Write-Host "      Time: $($proj.Timestamp) | Date: $($proj.ReadableTime)"
            
            if ($windowTitle -match $safeName) {
                Write-Host "      Result: [MATCH] (Selected)"
                $targetProject = $proj
                break 
            } else {
                Write-Host "      Result: No Match"
            }
            $rank++
        }

        if (-not $targetProject) {
            Write-Host "No project matches the current window title."
            Start-Sleep $checkInterval
            continue
        }

        $projectPath = $targetProject.Path
        Write-Host ""
        Write-Host ">> Target Identified: $projectPath"

        # 7. Launch Execution
        if ((Test-Path $projectPath) -and ((-not $VSCodeOpened) -or ($projectPath -ne $lastDetectedPath))) {

            Write-Host "Waiting $delayBeforeOpen seconds..."
            
            $abort = $false
            for ($i = $delayBeforeOpen; $i -gt 0; $i--) {
                $curr = Get-Process | Where-Object { $_.ProcessName -like "studio*" } | Select-Object -First 1
                
                if (-not $curr) { $abort = $true; break }
                if ($curr.MainWindowTitle -match "Welcome to Android Studio") { $abort = $true; break }
                
                Write-Host "Opening VS Code in $i seconds..."
                Start-Sleep 1
            }

            if (-not $abort) {
                Write-Host "Launching VS Code..."
                Start-Process "code" -ArgumentList "`"$projectPath`""
                $VSCodeOpened = $true
                $lastDetectedPath = $projectPath
                Write-Host "Done."
            } else {
                Write-Host "Launch Aborted."
                $VSCodeOpened = $false
            }
        }
        else {
            # Silent idle
        }
    }
    catch {
        Write-Host "Error: $_"
    }

    Start-Sleep $checkInterval
}