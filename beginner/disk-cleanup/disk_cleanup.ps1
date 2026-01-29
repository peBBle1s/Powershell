# Disk Cleanup - Safe Mode with Confirmation

$daysOld = 7
$cutoffDate = (Get-Date).AddDays(-$daysOld)

$paths = @(
    $env:TEMP,
    "C:\Windows\Temp"
)

$totalFreed = 0

foreach ($path in $paths) {

    Write-Host "`nScanning: $path" -ForegroundColor Cyan

    if (-not (Test-Path $path)) {
        Write-Host "Path not found, skipping..."
        continue
    }

    $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue |
             Where-Object { $_.LastWriteTime -lt $cutoffDate }

    if ($files.Count -eq 0) {
        Write-Host "No old files found."
        continue
    }

    $sizeBefore = ($files | Measure-Object Length -Sum).Sum
    Write-Host "Files found:" $files.Count
    Write-Host "Size:" ([math]::Round($sizeBefore / 1MB, 2)) "MB"

    $confirm = Read-Host "Delete these files? (Y/N)"

    if ($confirm -ne "Y") {
        Write-Host "Skipped cleanup for this path."
        continue
    }

    foreach ($file in $files) {
        try {
            Remove-Item $file.FullName -Force -ErrorAction Stop
            $totalFreed += $file.Length
        }
        catch {
            # Ignore access denied files
        }
    }

    Write-Host "Cleanup done for this path."
}

Write-Host "`nTotal space freed:" ([math]::Round($totalFreed / 1MB, 2)) "MB" -ForegroundColor Green
