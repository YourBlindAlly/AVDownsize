# AVDownsize uninstall — removes the right-click context menu entries.
# Your settings in AppData are preserved. Delete the AVDownsize folder there if you want a clean removal.

$root = "HKCU:\Software\Classes\SystemFileAssociations\video\shell\AVDownsize"

if (Test-Path $root) {
    Remove-Item -Path $root -Recurse -Force
    Write-Host "AVDownsize context menu entries removed."
    Write-Host ""
    Write-Host "Note: Your settings file was kept at:"
    Write-Host "  $(Join-Path $env:APPDATA 'AVDownsize\settings.json')"
    Write-Host "Delete that folder manually if you want a complete removal."
} else {
    Write-Host "AVDownsize context menu entries were not found. Nothing to remove."
}

Write-Host ""
Read-Host "Press Enter to close"
