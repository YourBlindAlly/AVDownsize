# AVDownsize uninstall — removes all right-click context menu entries.
# Your settings in AppData are preserved. Delete the AVDownsize folder there if you want a clean removal.

$extensions = @("video", ".mp4", ".mov", ".avi", ".mkv", ".wmv", ".m4v", ".flv", ".webm", ".mpg", ".mpeg", ".ts", ".mts", ".m2ts", ".3gp")

$removed = 0
foreach ($ext in $extensions) {
    $shellRoot = "HKCU:\Software\Classes\SystemFileAssociations\$ext\shell"
    if (Test-Path $shellRoot) {
        Get-ChildItem $shellRoot | Where-Object { $_.PSChildName -like "AVDownsize*" } | ForEach-Object {
            Remove-Item $_.PSPath -Recurse -Force
            $removed++
        }
    }
}

if ($removed -gt 0) {
    Write-Host "AVDownsize context menu entries removed."
} else {
    Write-Host "AVDownsize context menu entries were not found. Nothing to remove."
}

Write-Host ""
Write-Host "Note: Your settings file was kept at:"
Write-Host "  $(Join-Path $env:APPDATA 'AVDownsize\settings.json')"
Write-Host "Delete that folder manually if you want a complete removal."
Write-Host ""
Read-Host "Press Enter to close"
