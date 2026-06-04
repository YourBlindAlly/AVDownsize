param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile,
    [ValidateSet('auto', 'smaller', 'quality')]
    [string]$Mode = 'auto',
    [switch]$PassThru
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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

# --- Logging ---

$logDir = Join-Path $env:APPDATA "AVDownsize\logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

# Keep only the 20 most recent log files
Get-ChildItem $logDir -Filter "*.log" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -Skip 20 |
    Remove-Item -Force -ErrorAction SilentlyContinue

$logFile = Join-Path $logDir ("avdownsize_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

function Write-Log($msg) {
    $ts = Get-Date -Format "HH:mm:ss"
    "$ts  $msg" | Add-Content -Path $logFile -Encoding UTF8
}

Write-Log "=== AVDownsize Run Started ==="
Write-Log "Input:    $InputFile"
Write-Log "Mode:     $Mode"
Write-Log "PassThru: $($PassThru.IsPresent)"

# --- Dialogs (used only when not in PassThru mode) ---

function Show-Notice($title, $msg) {
    $f = New-Object System.Windows.Forms.Form
    $f.Text = $title
    $f.TopMost = $true
    $f.StartPosition = "CenterScreen"
    $f.FormBorderStyle = "FixedDialog"
    $f.MaximizeBox = $false
    $f.MinimizeBox = $false
    $f.Size = New-Object System.Drawing.Size(440, 230)

    $txt = New-Object System.Windows.Forms.TextBox
    $txt.Location = New-Object System.Drawing.Point(20, 20)
    $txt.Size = New-Object System.Drawing.Size(400, 140)
    $txt.Text = $msg
    $txt.ReadOnly = $true
    $txt.BorderStyle = "None"
    $txt.BackColor = $f.BackColor
    $txt.Multiline = $true
    $txt.TabStop = $true
    $f.Controls.Add($txt)

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "OK"
    $btn.DialogResult = "OK"
    $btn.Location = New-Object System.Drawing.Point(180, 165)
    $btn.Size = New-Object System.Drawing.Size(80, 28)
    $f.Controls.Add($btn)
    $f.AcceptButton = $btn

    $f.ActiveControl = $txt
    $f.ShowDialog() | Out-Null
    $f.Dispose()
}

function Show-Error($msg) { Show-Notice "AVDownsize Error" $msg }

# --- FFmpeg version check ---

try {
    $verLine = & $s.ffmpegPath -version 2>&1 | Select-Object -First 1
    Write-Log "FFmpeg version line: $verLine"
    if ($verLine -match 'ffmpeg version (\d+)\.(\d+)') {
        $ffMajor = [int]$Matches[1]
        $ffMinor = [int]$Matches[2]
        Write-Log "FFmpeg version parsed: $ffMajor.$ffMinor"
        if ($ffMajor -lt 4) {
            $warnMsg = "FFmpeg version $ffMajor.$ffMinor is older than the recommended minimum of 4.0. You may encounter errors. Please update FFmpeg from ffmpeg.org."
            Write-Log "WARNING: $warnMsg"
            if (-not $PassThru) { Show-Notice "AVDownsize Warning" $warnMsg }
        }
    } else {
        Write-Log "FFmpeg version could not be parsed from: $verLine"
    }
} catch {
    Write-Log "ERROR: Could not run ffmpeg to check version. $_"
}

# --- Input file ---

if (-not (Test-Path $InputFile)) {
    Write-Log "ERROR: Input file not found: $InputFile"
    if ($PassThru) { return [PSCustomObject]@{ Success = $false; Error = "File not found: $InputFile" } }
    Show-Error "File not found:`n$InputFile"
    exit 1
}

$file = Get-Item $InputFile
$originalSize = $file.Length
Write-Log "File size: $([math]::Round($originalSize / 1MB, 2)) MB"

# --- FFprobe ---

$probeArgs = @("-v", "quiet", "-print_format", "json", "-show_streams", "-show_format", $InputFile)
Write-Log "Running ffprobe..."
$probeLines = & $s.ffprobePath @probeArgs
$probeJson  = $probeLines -join "`n"
Write-Log "FFprobe output: $probeJson"

try {
    $probe = $probeJson | ConvertFrom-Json
} catch {
    $errMsg = "Could not read video metadata for: $($file.Name). Is ffprobe installed and on your PATH?"
    Write-Log "ERROR: Failed to parse ffprobe JSON. $_"
    if ($PassThru) { return [PSCustomObject]@{ Success = $false; Error = $errMsg } }
    Show-Error "Could not read video metadata for:`n$($file.Name)`n`nIs ffprobe installed and on your PATH?"
    exit 1
}

# --- Stream detection ---

$allStreamTypes = $probe.streams | ForEach-Object { $_.codec_type } | Sort-Object -Unique
Write-Log "Streams found: $($allStreamTypes -join ', ')"

$videoStream = $probe.streams | Where-Object { $_.codec_type -eq "video" } | Select-Object -First 1
if (-not $videoStream) {
    $detail = if ($allStreamTypes) {
        "Streams found: $($allStreamTypes -join ', ').`nThis may be an audio-only file saved with a video extension."
    } else {
        "No streams found at all. The file may be corrupt or incomplete."
    }
    $errMsg = "No video stream found in: $($file.Name)`n`n$detail"
    Write-Log "ERROR: $errMsg"
    if ($PassThru) { return [PSCustomObject]@{ Success = $false; Error = $errMsg } }
    Show-Error $errMsg
    exit 1
}

$codec  = $videoStream.codec_name
$width  = [int]$videoStream.width
$height = [int]$videoStream.height
Write-Log "Video stream: codec=$codec, resolution=${width}x${height}"

# --- Quality value ---

$qval = switch ($Mode) {
    'auto'    { if ($codec -eq "hevc") { 28 } else { 26 } }
    'smaller' { 32 }
    'quality' { 22 }
}
Write-Log "Quality value (CRF/QP): $qval"

# --- Scale filter ---

$scaleFilter = @()
if ($s.downscale4K -and $Mode -ne 'quality' -and ($width -ge 3840 -or $height -ge 2160)) {
    $scaleFilter = @("-vf", "scale=1920:1080:flags=lanczos")
    Write-Log "4K downscale filter applied"
}

# --- Output path ---

$outDir = if ($s.outputFolder -and (Test-Path $s.outputFolder)) { $s.outputFolder } else { $file.DirectoryName }
$outBase = $file.BaseName + $s.outputSuffix + ".mp4"
$outPath = Join-Path $outDir $outBase

$n = 1
while (Test-Path $outPath) {
    $outPath = Join-Path $outDir ($file.BaseName + $s.outputSuffix + "_$n.mp4")
    $n++
}
Write-Log "Output path: $outPath"

# --- Encoder selection ---

# Uses a real short encode as the test, not just a null output, so encoders
# that pass a trivial test but fail on real content are caught.
function Test-Encoder($encoderName, $extraArgs) {
    $tmp = [System.IO.Path]::GetTempFileName() + ".mp4"
    $testArgs = @("-f", "lavfi", "-i", "color=black:s=128x128:d=1", "-c:v", $encoderName) + $extraArgs + @("-t", "1", "-y", $tmp)
    & $s.ffmpegPath @testArgs 2>&1 | Out-Null
    $ok = $LASTEXITCODE -eq 0 -and (Test-Path $tmp)
    if (Test-Path $tmp) { Remove-Item $tmp -Force }
    Write-Log "  Encoder test $encoderName : $(if ($ok) { 'PASS' } else { 'FAIL' })"
    return $ok
}

Write-Log "Testing encoders..."
$encoderName = $null
$videoArgs = if (Test-Encoder "hevc_qsv" @("-global_quality", "28")) {
    $encoderName = "Intel Quick Sync (hevc_qsv)"
    @("-c:v", "hevc_qsv", "-global_quality", $qval, "-preset", "medium", "-tag:v", "hvc1")
} elseif (Test-Encoder "hevc_nvenc" @("-cq", "28")) {
    $encoderName = "NVIDIA NVENC (hevc_nvenc)"
    @("-c:v", "hevc_nvenc", "-rc:v", "vbr", "-cq", $qval, "-preset", "p4", "-tag:v", "hvc1")
} elseif (Test-Encoder "hevc_amf" @("-rc", "cqp", "-qp_i", "28", "-qp_p", "28")) {
    $encoderName = "AMD AMF (hevc_amf)"
    @("-c:v", "hevc_amf", "-rc", "cqp", "-qp_i", $qval, "-qp_p", $qval, "-quality", "balanced", "-tag:v", "hvc1")
} else {
    $encoderName = "Software (libx265)"
    @("-c:v", "libx265", "-crf", $qval, "-preset", "fast", "-tag:v", "hvc1")
}
Write-Log "Selected encoder: $encoderName"

# --- FFmpeg encode ---

$ffArgs = @("-i", $InputFile) + $videoArgs + $scaleFilter + @(
    "-c:a", "aac",
    "-b:a", "128k",
    "-movflags", "+faststart",
    $outPath
)
Write-Log "FFmpeg command: $($s.ffmpegPath) $($ffArgs -join ' ')"

$ffOutput = & $s.ffmpegPath @ffArgs 2>&1
$ffExitCode = $LASTEXITCODE
Write-Log "FFmpeg exit code: $ffExitCode"
if ($ffOutput) { Write-Log "FFmpeg output: $($ffOutput -join ' | ')" }

if ($ffExitCode -ne 0 -or -not (Test-Path $outPath)) {
    $errMsg = "Compression failed for: $($file.Name). Encoder tried: $encoderName. Check that ffmpeg is working correctly. See log for details: $logFile"
    Write-Log "ERROR: $errMsg"
    if ($PassThru) { return [PSCustomObject]@{ Success = $false; Error = $errMsg } }
    Show-Error "Compression failed for:`n$($file.Name)`n`nEncoder tried: $encoderName`nCheck that ffmpeg is working correctly.`n`nLog: $logFile"
    exit 1
}

# --- Result ---

$newSize   = (Get-Item $outPath).Length
$reduction = [math]::Round((1 - $newSize / $originalSize) * 100)
$origMB    = [math]::Round($originalSize / 1MB, 1)
$newMB     = [math]::Round($newSize / 1MB, 1)

Write-Log "SUCCESS: $origMB MB -> $newMB MB ($reduction% reduction)"
Write-Log "=== AVDownsize Run Complete ==="

if ($s.deleteOriginal) {
    Remove-Item $InputFile -Force
    Write-Log "Original deleted."
}

if ($PassThru) {
    return [PSCustomObject]@{
        Success     = $true
        FileName    = $file.Name
        OrigMB      = $origMB
        NewMB       = $newMB
        Reduction   = $reduction
        EncoderName = $encoderName
        LogFile     = $logFile
    }
}

if ($s.showSummary) {
    $msg = "File: $($file.Name)`nOriginal:   $origMB MB`nCompressed: $newMB MB`nReduced by: $reduction%`nEncoder:    $encoderName"
    Show-Notice "AVDownsize Complete" $msg
}
