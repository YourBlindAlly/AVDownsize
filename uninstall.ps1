# AVDownsize uninstall — removes all right-click context menu entries.
# Your settings in AppData are preserved. Delete the AVDownsize folder there if you want a clean removal.

$roots = @("HKCU:\Software\Classes\SystemFileAssociations\video\shell\AVDownsize")

$extensions = @(".mp4", ".mov", ".avi", ".mkv", ".wmv", ".m4v", ".flv", ".webm", ".mpg", ".mpeg", ".ts", ".mts", ".m2ts", ".3gp")
foreach ($ext in $extensions) {
    $roots += "HKCU:\Software\Classes\SystemFileAssociations\$ext\shell\AVDownsize"
}

$removed = 0
foreach ($root in $roots) {
    if (Test-Path $root) {
        Remove-Item -Path $root -Recurse -Force
        $removed++
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
