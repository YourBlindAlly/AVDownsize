param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile,
    [ValidateSet('auto', 'smaller', 'quality')]
    [string]$Mode = 'auto'
)

Add-Type -AssemblyName System.Windows.Forms

$settingsPath = Join-Path $env:APPDATA "AVDownsize\settings.json"
$defaults = @{
    ffmpegPath     = "ffmpeg"
    ffprobePath    = "ffprobe"
    outputFolder   = ""
    deleteOriginal = $false
    outputSuffix   = "_compressed"
    downscale4K    = $true
    showSummary    = $true
}

if (Test-Path $settingsPath) {
    $s = Get-Content $settingsPath -Raw | ConvertFrom-Json
    foreach ($key in $defaults.Keys) {
        if ($null -eq $s.$key) {
            $s | Add-Member -NotePropertyName $key -NotePropertyValue $defaults[$key] -Force
        }
    }
} else {
    $s = [PSCustomObject]$defaults
}

function Show-Error($msg) {
    [System.Windows.Forms.MessageBox]::Show($msg, "AVDownsize Error", 0, 16) | Out-Null
}

if (-not (Test-Path $InputFile)) {
    Show-Error "File not found:`n$InputFile"
    exit 1
}

$file = Get-Item $InputFile
$originalSize = $file.Length

# Probe video metadata (stdout only — ffprobe writes JSON to stdout, info to stderr)
$probeArgs = @("-v", "quiet", "-print_format", "json", "-show_streams", "-show_format", $InputFile)
$probeLines = & $s.ffprobePath @probeArgs
$probeJson  = $probeLines -join "`n"

try {
    $probe = $probeJson | ConvertFrom-Json
} catch {
    Show-Error "Could not read video metadata for:`n$($file.Name)`n`nIs ffprobe installed and on your PATH?"
    exit 1
}

$videoStream = $probe.streams | Where-Object { $_.codec_type -eq "video" } | Select-Object -First 1
if (-not $videoStream) {
    Show-Error "No video stream found in:`n$($file.Name)"
    exit 1
}

$codec  = $videoStream.codec_name
$width  = [int]$videoStream.width
$height = [int]$videoStream.height

# CRF: lower = better quality / larger file. H.265 sweet spots: 22 high, 26 balanced, 32 small.
# If already HEVC in auto mode, bump CRF slightly — re-encoding HEVC-to-HEVC gains less than H264-to-HEVC.
$crf = switch ($Mode) {
    'auto'    { if ($codec -eq "hevc") { 28 } else { 26 } }
    'smaller' { 32 }
    'quality' { 22 }
}

# Downscale 4K to 1080p unless user chose high-quality mode
$scaleFilter = @()
if ($s.downscale4K -and $Mode -ne 'quality' -and ($width -ge 3840 -or $height -ge 2160)) {
    $scaleFilter = @("-vf", "scale=1920:1080:flags=lanczos")
}

# Determine output path
$outDir = if ($s.outputFolder -and (Test-Path $s.outputFolder)) { $s.outputFolder } else { $file.DirectoryName }
$outBase = $file.BaseName + $s.outputSuffix + ".mp4"
$outPath = Join-Path $outDir $outBase

$n = 1
while (Test-Path $outPath) {
    $outPath = Join-Path $outDir ($file.BaseName + $s.outputSuffix + "_$n.mp4")
    $n++
}

# Build ffmpeg arguments
$ffArgs = @(
    "-i", $InputFile,
    "-c:v", "libx265",
    "-crf", $crf,
    "-preset", "medium"
) + $scaleFilter + @(
    "-c:a", "aac",
    "-b:a", "128k",
    "-tag:v", "hvc1",        # Apple QuickTime / iPhone compatibility
    "-movflags", "+faststart", # Enable streaming / fast open
    $outPath
)

$proc = Start-Process -FilePath $s.ffmpegPath -ArgumentList $ffArgs -Wait -PassThru -WindowStyle Hidden

if ($proc.ExitCode -ne 0 -or -not (Test-Path $outPath)) {
    Show-Error "Compression failed for:`n$($file.Name)`n`nCheck that ffmpeg supports libx265 (H.265 encoding)."
    exit 1
}

$newSize   = (Get-Item $outPath).Length
$reduction = [math]::Round((1 - $newSize / $originalSize) * 100)
$origMB    = [math]::Round($originalSize / 1MB, 1)
$newMB     = [math]::Round($newSize / 1MB, 1)

if ($s.showSummary) {
    $msg = "Compression complete.`n`nFile: $($file.Name)`nOriginal:   $origMB MB`nCompressed: $newMB MB`nReduced by: $reduction%"
    [System.Windows.Forms.MessageBox]::Show($msg, "AVDownsize Complete", 0, 64) | Out-Null
}

if ($s.deleteOriginal) {
    Remove-Item $InputFile -Force
}
