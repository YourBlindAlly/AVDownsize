# AVDownsize setup — registers the right-click context menu for video files.
# Run this once after downloading. No administrator rights required.

$scriptDir      = $PSScriptRoot
$compressScript = Join-Path $scriptDir "compress.ps1"
$settingsScript = Join-Path $scriptDir "settings.ps1"

foreach ($f in @($compressScript, $settingsScript)) {
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

$ps = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -File"

# Submenu items. Child items in a Windows cascading menu require MUIVerb (not Default) for their label.
$subItems = @(
    @{ id = "01_auto";     label = "Auto Compress (Recommended)"; cmd = "$ps `"$compressScript`" -InputFile `"%1`" -Mode auto" }
    @{ id = "02_smaller";  label = "Compress Smaller";            cmd = "$ps `"$compressScript`" -InputFile `"%1`" -Mode smaller" }
    @{ id = "03_quality";  label = "Compress High Quality";       cmd = "$ps `"$compressScript`" -InputFile `"%1`" -Mode quality" }
    @{ id = "04_settings"; label = "Settings";                    cmd = "powershell.exe -ExecutionPolicy Bypass -File `"$settingsScript`"" }
)

$extensions = @("video", ".mp4", ".mov", ".avi", ".mkv", ".wmv", ".m4v", ".flv", ".webm", ".mpg", ".mpeg", ".ts", ".mts", ".m2ts", ".3gp")

foreach ($ext in $extensions) {
    # Remove any old entries (flat or cascading) so we start clean
    foreach ($old in @("AVDownsize", "AVDownsize_1_auto", "AVDownsize_2_smaller", "AVDownsize_3_quality", "AVDownsize_4_settings")) {
        $oldPath = "HKCU:\Software\Classes\SystemFileAssociations\$ext\shell\$old"
        if (Test-Path $oldPath) { Remove-Item -Path $oldPath -Recurse -Force }
    }

    # Create cascading parent
    $root = "HKCU:\Software\Classes\SystemFileAssociations\$ext\shell\AVDownsize"
    New-Item -Path $root -Force | Out-Null
    Set-ItemProperty -Path $root -Name "MUIVerb"     -Value "AVDownsize"
    Set-ItemProperty -Path $root -Name "SubCommands" -Value ""
    New-Item -Path "$root\shell" -Force | Out-Null

    # Create child items — MUIVerb is required for labels inside a cascading menu
    foreach ($item in $subItems) {
        $itemPath = "$root\shell\$($item.id)"
        New-Item -Path $itemPath -Force | Out-Null
        Set-ItemProperty -Path $itemPath -Name "MUIVerb" -Value $item.label
        New-Item -Path "$itemPath\command" -Force | Out-Null
        Set-ItemProperty -Path "$itemPath\command" -Name "(Default)" -Value $item.cmd
    }
}

Write-Host ""
Write-Host "AVDownsize installed successfully."
Write-Host "Right-click any video file in File Explorer to use it."
Write-Host ""
Write-Host "Scripts:  $scriptDir"
Write-Host "Settings: $settingsFile"
Write-Host ""
Read-Host "Press Enter to close"
