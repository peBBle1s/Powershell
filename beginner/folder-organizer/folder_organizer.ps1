# Folder Organizer - Desktop (Safe & Re-runnable)

$desktopPath = [Environment]::GetFolderPath("Desktop")

$rules = @{
    Images    = @(".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp")
    Documents = @(".pdf", ".docx", ".doc", ".txt", ".xlsx", ".pptx")
    Videos    = @(".mp4", ".mkv", ".avi", ".mov")
    Music     = @(".mp3", ".wav", ".flac")
    Archives  = @(".zip", ".rar", ".7z", ".tar", ".gz")
}

Write-Host "Organizing Desktop:" $desktopPath -ForegroundColor Cyan

# Create folders if they don't exist
foreach ($folder in $rules.Keys) {
    $folderPath = Join-Path $desktopPath $folder
    if (-not (Test-Path $folderPath)) {
        New-Item -ItemType Directory -Path $folderPath | Out-Null
        Write-Host "Created folder:" $folder
    }
}

# Get files only (no folders)
$files = Get-ChildItem -Path $desktopPath -File

foreach ($file in $files) {

    # Skip PowerShell scripts
    if ($file.Extension -eq ".ps1") {
        continue
    }

    foreach ($rule in $rules.GetEnumerator()) {
        if ($rule.Value -contains $file.Extension.ToLower()) {

            $destination = Join-Path $desktopPath $rule.Key

            try {
                Move-Item -Path $file.FullName -Destination $destination -Force
                Write-Host "Moved $($file.Name) -> $($rule.Key)"
            }
            catch {
                Write-Host "Failed to move $($file.Name)" -ForegroundColor Yellow
            }

            break
        }
    }
}

Write-Host "`nDesktop organization complete." -ForegroundColor Green
