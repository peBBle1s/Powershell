param (
    [string]$TargetPath = [Environment]::GetFolderPath("Desktop")
)

# -------------------------------
# Validate path
# -------------------------------
if (-not (Test-Path $TargetPath)) {
    Write-Host "Path does not exist: $TargetPath" -ForegroundColor Red
    exit
}

Write-Host "Organizing folder: $TargetPath" -ForegroundColor Cyan

# -------------------------------
# File type rules
# -------------------------------
$rules = @{
    Images      = @(".jpg",".jpeg",".png",".gif",".bmp",".webp",".tiff",".ico",".heic")
    Documents   = @(".pdf",".doc",".docx",".txt",".rtf",".xls",".xlsx",".csv",".ppt",".pptx",".odt",".ods")
    Videos      = @(".mp4",".mkv",".avi",".mov",".wmv",".flv",".webm",".3gp")
    Music       = @(".mp3",".wav",".flac",".aac",".ogg",".m4a",".wma")
    Archives    = @(".zip",".rar",".7z",".tar",".gz",".bz2",".xz",".iso")
    Installers  = @(".exe",".msi",".msix",".appx",".bat",".cmd")
    Web         = @(".html",".htm",".css",".js",".json",".xml",".php")
    Code        = @(".ps1",".py",".java",".c",".cpp",".h",".cs",".go",".rs",".sh",".rb",".swift",".ts",".jsx",".tsx")
    Databases   = @(".db",".sqlite",".sqlite3",".mdb",".accdb")
    Logs        = @(".log",".tmp",".bak",".old",".dmp")
    Design      = @(".psd",".ai",".xd",".fig",".sketch",".dwg",".dxf")
    Config      = @(".ini",".cfg",".conf",".yml",".yaml",".eml",".msg")
    Data        = @(".dat",".bin",".pem",".key",".crt")
}

# -------------------------------
# Safety exclusions
# -------------------------------
$skipExtensions = @(".lnk", ".sys", ".dll")
$systemFiles    = @("desktop.ini", "thumbs.db")

# -------------------------------
# Create category folders
# -------------------------------
foreach ($folder in $rules.Keys + "Others") {
    $folderPath = Join-Path $TargetPath $folder
    if (-not (Test-Path $folderPath)) {
        New-Item -ItemType Directory -Path $folderPath | Out-Null
    }
}

# -------------------------------
# Get files (including hidden)
# -------------------------------
$files = Get-ChildItem -Path $TargetPath -File -Force

foreach ($file in $files) {

    # Skip system / dangerous files
    if (
        $skipExtensions -contains $file.Extension.ToLower() -or
        $systemFiles -contains $file.Name.ToLower() -or
        $file.Attributes -match "System"
    ) {
        continue
    }

    $moved = $false

    foreach ($rule in $rules.GetEnumerator()) {
        if ($rule.Value -contains $file.Extension.ToLower()) {

            $destination = Join-Path $TargetPath $rule.Key

            try {
                Move-Item -Path $file.FullName -Destination $destination -Force
                Write-Host "Moved $($file.Name) -> $($rule.Key)"
            }
            catch {
                Write-Host "Failed to move $($file.Name)" -ForegroundColor Yellow
            }

            $moved = $true
            break
        }
    }

    # Move unknown files to Others
    if (-not $moved) {
        try {
            Move-Item -Path $file.FullName -Destination (Join-Path $TargetPath "Others") -Force
            Write-Host "Moved $($file.Name) -> Others"
        }
        catch {
            Write-Host "Failed to move $($file.Name)" -ForegroundColor Yellow
        }
    }
}

Write-Host "Folder organization complete." -ForegroundColor Green
