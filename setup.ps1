# AVDownsize setup — registers the right-click context menu for video files.
# Run this once after downloading. No administrator rights required.

$scriptDir     = $PSScriptRoot
$chooserScript = Join-Path $scriptDir "chooser.ps1"

foreach ($f in @($chooserScript)) {
    if (-not (Test-Path $f)) {
        Write-Host "ERROR: Missing file: $f"
        Write-Host "Make sure you are running setup.ps1 from the AVDownsize folder."
        Read-Host "Press Enter to close"
        exit 1
    }
}

$settingsDir  = Join-Path $env:APPDATA "AVDownsize"
$settingsFile = Join-Path $settingsDir "settings.json"

if (-not (Test-Path $settingsDir)) { New-Item -ItemType Directory -Path $settingsDir | Out-Null }

if (-not (Test-Path $settingsFile)) {
    @{
        ffmpegPath     = "ffmpeg"
        ffprobePath    = "ffprobe"
        outputFolder   = ""
        deleteOriginal = $false
        outputSuffix   = "_compressed"
        downscale4K    = $true
        showSummary    = $true
    } | ConvertTo-Json | Set-Content $settingsFile -Encoding UTF8
    Write-Host "Created default settings at: $settingsFile"
}

$cmd = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$chooserScript`" -InputFile `"%1`""

$extensions = @("video", ".mp4", ".mov", ".avi", ".mkv", ".wmv", ".m4v", ".flv", ".webm", ".mpg", ".mpeg", ".ts", ".mts", ".m2ts", ".3gp")

foreach ($ext in $extensions) {
    # Remove all previous AVDownsize entries (any format we may have used before)
    $shellRoot = "HKCU:\Software\Classes\SystemFileAssociations\$ext\shell"
    if (Test-Path $shellRoot) {
        Get-ChildItem $shellRoot | Where-Object { $_.PSChildName -like "AVDownsize*" } | ForEach-Object {
            Remove-Item $_.PSPath -Recurse -Force
        }
    }

    # Single entry — opens chooser dialog
    $itemRoot = "HKCU:\Software\Classes\SystemFileAssociations\$ext\shell\AVDownsize"
    New-Item -Path $itemRoot -Force | Out-Null
    Set-ItemProperty -Path $itemRoot -Name "(Default)" -Value "AVDownsize"
    New-Item -Path "$itemRoot\command" -Force | Out-Null
    Set-ItemProperty -Path "$itemRoot\command" -Name "(Default)" -Value $cmd
}

Write-Host ""
Write-Host "AVDownsize installed successfully."
Write-Host "Right-click any video file in File Explorer to use it."
Write-Host ""
Write-Host "Scripts:  $scriptDir"
Write-Host "Settings: $settingsFile"
Write-Host ""
Read-Host "Press Enter to close"
