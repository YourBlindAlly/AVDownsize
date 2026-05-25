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

# Four flat menu entries per extension — no cascading submenu, more reliable across all systems
$menuItems = @(
    @{ id = "AVDownsize_1_auto";     label = "AVDownsize: Auto Compress";     cmd = "$ps `"$compressScript`" -InputFile `"%1`" -Mode auto" }
    @{ id = "AVDownsize_2_smaller";  label = "AVDownsize: Compress Smaller";  cmd = "$ps `"$compressScript`" -InputFile `"%1`" -Mode smaller" }
    @{ id = "AVDownsize_3_quality";  label = "AVDownsize: High Quality";      cmd = "$ps `"$compressScript`" -InputFile `"%1`" -Mode quality" }
    @{ id = "AVDownsize_4_settings"; label = "AVDownsize: Settings";          cmd = "powershell.exe -ExecutionPolicy Bypass -File `"$settingsScript`"" }
)

$extensions = @("video", ".mp4", ".mov", ".avi", ".mkv", ".wmv", ".m4v", ".flv", ".webm", ".mpg", ".mpeg", ".ts", ".mts", ".m2ts", ".3gp")

foreach ($ext in $extensions) {
    # Remove any old cascading menu entry first
    $oldRoot = "HKCU:\Software\Classes\SystemFileAssociations\$ext\shell\AVDownsize"
    if (Test-Path $oldRoot) { Remove-Item -Path $oldRoot -Recurse -Force }

    foreach ($item in $menuItems) {
        $itemRoot = "HKCU:\Software\Classes\SystemFileAssociations\$ext\shell\$($item.id)"
        New-Item -Path $itemRoot -Force | Out-Null
        Set-ItemProperty -Path $itemRoot -Name "(Default)" -Value $item.label
        New-Item -Path "$itemRoot\command" -Force | Out-Null
        Set-ItemProperty -Path "$itemRoot\command" -Name "(Default)" -Value $item.cmd
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
