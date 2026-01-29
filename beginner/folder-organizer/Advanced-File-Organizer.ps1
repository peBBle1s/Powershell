param (
    [Parameter(Mandatory)]
    [string]$TargetPath,

    [switch]$DryRun,
    [switch]$Undo,
    [switch]$CreateTask
)

# ===============================
# Load Config
# ===============================
$configPath = Join-Path $PSScriptRoot "organizer.config.json"
Write-Host "DEBUG: PSScriptRoot is currently: '$PSScriptRoot'" -ForegroundColor Magenta

if (-not (Test-Path $configPath)) {
    Write-Host "Config file missing: organizer.config.json" -ForegroundColor Red
    exit
}

$Config = Get-Content $configPath | ConvertFrom-Json

# ===============================
# Validate Target Path
# ===============================
if (-not (Test-Path $TargetPath)) {
    Write-Host "Target path does not exist: $TargetPath" -ForegroundColor Red
    exit
}

Write-Host "Target folder: $TargetPath" -ForegroundColor Cyan
if ($DryRun) { Write-Host "Mode: DRY-RUN" -ForegroundColor Yellow }

# ===============================
# Log paths
# ===============================
$LogFolder = Join-Path $TargetPath "_OrganizerLogs"
$CsvLog    = Join-Path $LogFolder "MoveLog.csv"

if (-not (Test-Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder | Out-Null
}

# ===============================
# UNDO MODE
# ===============================
if ($Undo) {
    if (-not (Test-Path $CsvLog)) {
        Write-Host "No log found. Cannot undo." -ForegroundColor Red
        exit
    }

    Import-Csv $CsvLog | ForEach-Object {
        if (Test-Path $_.DestinationPath) {
            Move-Item $_.DestinationPath $_.OriginalPath -Force
        }
    }

    Write-Host "Undo completed." -ForegroundColor Green
    exit
}

# ===============================
# Rules
# ===============================
$rules = @{
    Images      = @(".jpg",".jpeg",".png",".gif",".bmp",".webp",".jfif")
    Documents   = @(".pdf",".doc",".docx",".txt",".xlsx",".pptx",".csv")
    Videos      = @(".mp4",".mkv",".avi",".mov")
    Music       = @(".mp3",".wav",".flac")
    Archives    = @(".zip",".rar",".7z",".tar",".gz")
    Installers  = @(".exe",".msi")
    Web         = @(".html",".htm",".css",".js",".json",".xml")
}

$skipExtensions = @(".lnk",".sys",".dll")
$systemFiles   = @("desktop.ini","thumbs.db")

# ===============================
# Create folders
# ===============================
($rules.Keys + "Others" + "_OrganizerLogs") | ForEach-Object {
    $p = Join-Path $TargetPath $_
    if (-not (Test-Path $p)) {
        New-Item -ItemType Directory -Path $p | Out-Null
    }
}

# ===============================
# CSV header
# ===============================
if (-not (Test-Path $CsvLog)) {
@"
FileName,Extension,Category,IsHidden,OriginalPath,DestinationPath,Timestamp
"@ | Out-File $CsvLog -Encoding UTF8
}

# ===============================
# Process files
# ===============================
$filesMoved  = 0
$hiddenCount = 0

$files = Get-ChildItem -Path $TargetPath -File -Force

foreach ($file in $files) {

    if (
        $skipExtensions -contains $file.Extension.ToLower() -or
        $systemFiles -contains $file.Name.ToLower() -or
        $file.Attributes -match "System"
    ) { continue }

    $category = "Others"
    foreach ($rule in $rules.GetEnumerator()) {
        if ($rule.Value -contains $file.Extension.ToLower()) {
            $category = $rule.Key
            break
        }
    }

    $destFolder = Join-Path $TargetPath $category
    $destPath   = Join-Path $destFolder $file.Name
    $isHidden   = ($file.Attributes -match "Hidden")

    if ($isHidden) { $hiddenCount++ }

    "$($file.Name),$($file.Extension),$category,$isHidden,$($file.FullName),$destPath,$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" |
        Add-Content $CsvLog

    if (-not $DryRun) {
        Move-Item $file.FullName $destFolder -Force
    }

    $filesMoved++
}

Write-Host "Organization completed. Files moved: $filesMoved" -ForegroundColor Green

# ===============================
# EMAIL REPORT (ONLY IF FILES > 0)
# ===============================
if ($Config.Email.Enable -and $filesMoved -gt 0 -and -not $DryRun) {
    try {
        # Use saved credential
        $credFile = Join-Path $PSScriptRoot "gmail-cred.xml"
        $cred = Import-Clixml -Path $credFile

        $body = @"
Folder: $TargetPath
Files moved: $filesMoved
Hidden files: $hiddenCount
Log attached.
"@

        Send-MailMessage `
            -From $Config.Email.From `
            -To $Config.Email.To `
            -Subject $Config.Email.Subject `
            -Body $body `
            -Attachments $CsvLog `
            -SmtpServer $Config.Email.SMTPServer `
            -Port $Config.Email.Port `
            -UseSsl:$Config.Email.UseSSL `
            -Credential $cred
    }
    catch {
        Write-Host "Email failed: $_" -ForegroundColor Red
    }
}


# ===============================
# POPUP (DISABLED FOR SILENT TASKS)
# ===============================
if ($Config.Notification.ShowPopup -and -not $CreateTask) {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show(
        "Files moved: $filesMoved`nHidden files: $hiddenCount",
        "File Organizer"
    )
}

# ===============================
# SCHEDULED TASK (SILENT)
# ===============================
if ($CreateTask) {

    $taskName = "AutoFileOrganizer_$($TargetPath.GetHashCode())"

    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" -TargetPath `"$TargetPath`""

    $trigger = New-ScheduledTaskTrigger -Daily -At 10:00AM

    Register-ScheduledTask `
        -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Force

    Write-Host "Scheduled task created (silent mode)." -ForegroundColor Cyan
}