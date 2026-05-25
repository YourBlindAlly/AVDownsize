# AVDownsize setup — registers the right-click context menu for video files.
# Run this once after downloading. No administrator rights required.

$scriptDir      = $PSScriptRoot
$compressScript = Join-Path $scriptDir "compress.ps1"
$settingsScript = Join-Path $scriptDir "settings.ps1"

# Verify scripts are present
foreach ($f in @($compressScript, $settingsScript)) {
    if (-not (Test-Path $f)) {
        Write-Host "ERROR: Missing file: $f"
        Write-Host "Make sure you are running setup.ps1 from the AVDownsize folder."
        Read-Host "Press Enter to close"
        exit 1
    }
}

# Create AppData folder and default settings if not already present
$settingsDir  = Join-Path $env:APPDATA "AVDownsize"
$settingsFile = Join-Path $settingsDir "settings.json"

if (-not (Test-Path $settingsDir)) {
    New-Item -ItemType Directory -Path $settingsDir | Out-Null
}

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

$ps = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -File"

function Register-MenuRoot($root) {
    New-Item -Path $root -Force | Out-Null
    Set-ItemProperty -Path $root -Name "MUIVerb"     -Value "AVDownsize - Compress Video"
    Set-ItemProperty -Path $root -Name "SubCommands" -Value ""
    New-Item -Path "$root\shell" -Force | Out-Null

    $items = @(
        @("01_auto",     "Auto Compress (Recommended)",  "$ps `"$compressScript`" -InputFile `"%1`" -Mode auto"),
        @("02_smaller",  "Compress Smaller",             "$ps `"$compressScript`" -InputFile `"%1`" -Mode smaller"),
        @("03_quality",  "Compress High Quality",        "$ps `"$compressScript`" -InputFile `"%1`" -Mode quality"),
        @("04_settings", "Settings",                     "powershell.exe -ExecutionPolicy Bypass -File `"$settingsScript`"")
    )

    foreach ($item in $items) {
        $itemPath = "$root\shell\$($item[0])"
        New-Item -Path $itemPath -Force | Out-Null
        Set-ItemProperty -Path $itemPath -Name "(Default)" -Value $item[1]
        New-Item -Path "$itemPath\command" -Force | Out-Null
        Set-ItemProperty -Path "$itemPath\command" -Name "(Default)" -Value $item[2]
    }
}

# Register for the generic video perceived type (covers most files on most systems)
Register-MenuRoot "HKCU:\Software\Classes\SystemFileAssociations\video\shell\AVDownsize"

# Also register for specific extensions so files not tagged as video type are covered
$extensions = @(".mp4", ".mov", ".avi", ".mkv", ".wmv", ".m4v", ".flv", ".webm", ".mpg", ".mpeg", ".ts", ".mts", ".m2ts", ".3gp")
foreach ($ext in $extensions) {
    Register-MenuRoot "HKCU:\Software\Classes\SystemFileAssociations\$ext\shell\AVDownsize"
}

Write-Host ""
Write-Host "AVDownsize installed successfully."
Write-Host "Right-click any video file in File Explorer to use it."
Write-Host ""
Write-Host "Scripts:  $scriptDir"
Write-Host "Settings: $settingsFile"
Write-Host ""
Read-Host "Press Enter to close"
