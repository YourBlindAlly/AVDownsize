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

# TopMost form used for all notifications so they appear in front of every window.
# Only used when compress.ps1 is invoked standalone (not via chooser.ps1 -PassThru).
function Show-Notice($title, $msg) {
    $f = New-Object System.Windows.Forms.Form
    $f.Text = $title
    $f.TopMost = $true
    $f.StartPosition = "CenterScreen"
    $f.FormBorderStyle = "FixedDialog"
    $f.MaximizeBox = $false
    $f.MinimizeBox = $false
    $f.Size = New-Object System.Drawing.Size(440, 230)

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.Size = New-Object System.Drawing.Size(400, 140)
    $lbl.Text = $msg
    $f.Controls.Add($lbl)

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "OK"
    $btn.DialogResult = "OK"
    $btn.Location = New-Object System.Drawing.Point(180, 165)
    $btn.Size = New-Object System.Drawing.Size(80, 28)
    $f.Controls.Add($btn)
    $f.AcceptButton = $btn

    $f.ShowDialog() | Out-Null
    $f.Dispose()
}

function Show-Error($msg) { Show-Notice "AVDownsize Error" $msg }

if (-not (Test-Path $InputFile)) {
    if ($PassThru) { return [PSCustomObject]@{ Success = $false; Error = "File not found: $InputFile" } }
    Show-Error "File not found:`n$InputFile"
    exit 1
}

$file = Get-Item $InputFile
$originalSize = $file.Length

$probeArgs = @("-v", "quiet", "-print_format", "json", "-show_streams", "-show_format", $InputFile)
$probeLines = & $s.ffprobePath @probeArgs
$probeJson  = $probeLines -join "`n"

try {
    $probe = $probeJson | ConvertFrom-Json
} catch {
    if ($PassThru) { return [PSCustomObject]@{ Success = $false; Error = "Could not read video metadata for: $($file.Name). Is ffprobe installed and on your PATH?" } }
    Show-Error "Could not read video metadata for:`n$($file.Name)`n`nIs ffprobe installed and on your PATH?"
    exit 1
}

$videoStream = $probe.streams | Where-Object { $_.codec_type -eq "video" } | Select-Object -First 1
if (-not $videoStream) {
    if ($PassThru) { return [PSCustomObject]@{ Success = $false; Error = "No video stream found in: $($file.Name)" } }
    Show-Error "No video stream found in:`n$($file.Name)"
    exit 1
}

$codec  = $videoStream.codec_name
$width  = [int]$videoStream.width
$height = [int]$videoStream.height

# CRF/quality value: lower = better quality, larger file
$qval = switch ($Mode) {
    'auto'    { if ($codec -eq "hevc") { 28 } else { 26 } }
    'smaller' { 32 }
    'quality' { 22 }
}

$scaleFilter = @()
if ($s.downscale4K -and $Mode -ne 'quality' -and ($width -ge 3840 -or $height -ge 2160)) {
    $scaleFilter = @("-vf", "scale=1920:1080:flags=lanczos")
}

$outDir = if ($s.outputFolder -and (Test-Path $s.outputFolder)) { $s.outputFolder } else { $file.DirectoryName }
$outBase = $file.BaseName + $s.outputSuffix + ".mp4"
$outPath = Join-Path $outDir $outBase

$n = 1
while (Test-Path $outPath) {
    $outPath = Join-Path $outDir ($file.BaseName + $s.outputSuffix + "_$n.mp4")
    $n++
}

# Auto-detect hardware encoder. Uses a real short encode as the test, not just a
# null output, so encoders that pass a trivial test but fail on real content are caught.
function Test-Encoder($encoderName, $extraArgs) {
    $tmp = [System.IO.Path]::GetTempFileName() + ".mp4"
    $testArgs = @("-f", "lavfi", "-i", "color=black:s=128x128:d=1", "-c:v", $encoderName) + $extraArgs + @("-t", "1", "-y", $tmp)
    & $s.ffmpegPath @testArgs 2>&1 | Out-Null
    $ok = $LASTEXITCODE -eq 0 -and (Test-Path $tmp)
    if (Test-Path $tmp) { Remove-Item $tmp -Force }
    return $ok
}

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

$ffArgs = @("-i", $InputFile) + $videoArgs + $scaleFilter + @(
    "-c:a", "aac",
    "-b:a", "128k",
    "-movflags", "+faststart",
    $outPath
)

# Use the call operator with splatting — each array element is passed as a
# separate argument, so paths with spaces are handled correctly without quoting.
& $s.ffmpegPath @ffArgs 2>&1 | Out-Null
$ffExitCode = $LASTEXITCODE

if ($ffExitCode -ne 0 -or -not (Test-Path $outPath)) {
    if ($PassThru) { return [PSCustomObject]@{ Success = $false; Error = "Compression failed for: $($file.Name). Encoder tried: $encoderName. Check that ffmpeg is working correctly." } }
    Show-Error "Compression failed for:`n$($file.Name)`n`nEncoder tried: $encoderName`nCheck that ffmpeg is working correctly."
    exit 1
}

$newSize   = (Get-Item $outPath).Length
$reduction = [math]::Round((1 - $newSize / $originalSize) * 100)
$origMB    = [math]::Round($originalSize / 1MB, 1)
$newMB     = [math]::Round($newSize / 1MB, 1)

if ($s.deleteOriginal) {
    Remove-Item $InputFile -Force
}

if ($PassThru) {
    return [PSCustomObject]@{
        Success     = $true
        FileName    = $file.Name
        OrigMB      = $origMB
        NewMB       = $newMB
        Reduction   = $reduction
        EncoderName = $encoderName
    }
}

if ($s.showSummary) {
    $msg = "File: $($file.Name)`nOriginal:   $origMB MB`nCompressed: $newMB MB`nReduced by: $reduction%`nEncoder:    $encoderName"
    Show-Notice "AVDownsize Complete" $msg
}
