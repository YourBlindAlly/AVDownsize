# AVDownsize uninstall — removes all right-click context menu entries.
# Your settings in AppData are preserved. Delete the AVDownsize folder there if you want a clean removal.

$ids = @("AVDownsize", "AVDownsize_1_auto", "AVDownsize_2_smaller", "AVDownsize_3_quality", "AVDownsize_4_settings")
$extensions = @("video", ".mp4", ".mov", ".avi", ".mkv", ".wmv", ".m4v", ".flv", ".webm", ".mpg", ".mpeg", ".ts", ".mts", ".m2ts", ".3gp")

$removed = 0
foreach ($ext in $extensions) {
    foreach ($id in $ids) {
        $path = "HKCU:\Software\Classes\SystemFileAssociations\$ext\shell\$id"
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force
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
