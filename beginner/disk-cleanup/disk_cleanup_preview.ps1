# Disk Cleanup - Preview Mode

$daysOld = 7
$cutoffDate = (Get-Date).AddDays(-$daysOld)
$tempPath = $env:TEMP

Write-Host "Scanning Temp Folder:" $tempPath
Write-Host "Files older than $daysOld days`n"

$files = Get-ChildItem -Path $tempPath -Recurse -File -ErrorAction SilentlyContinue |
         Where-Object { $_.LastWriteTime -lt $cutoffDate }

$totalSize = ($files | Measure-Object -Property Length -Sum).Sum

Write-Host "Files found:" $files.Count
Write-Host "Total size:" ([math]::Round($totalSize / 1MB, 2)) "MB"
