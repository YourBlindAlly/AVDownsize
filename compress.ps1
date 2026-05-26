param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile,
    [ValidateSet('auto', 'smaller', 'quality')]
    [string]$Mode = 'auto'
)

Add-Type -AssemblyName System.Windows.Forms

# Hide the console window immediately using the Windows API
Add-Type -Name ConsoleHelper -Namespace AVD -MemberDefinition '
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]   public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'
$hwnd = [AVD.ConsoleHelper]::GetConsoleWindow()
if ($hwnd -ne [IntPtr]::Zero) { [AVD.ConsoleHelper]::ShowWindow($hwnd, 0) | Out-Null }

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
    [System.Windows.Forms.MessageBox]::Show($msg, "AVDownsize Error", `
        [System.Windows.Forms.MessageBoxButtons]::OK, `
        [System.Windows.Forms.MessageBoxIcon]::Error, `
        [System.Windows.Forms.MessageBoxDefaultButton]::Button1, `
        [System.Windows.Forms.MessageBoxOptions]::DefaultDesktopOnly) | Out-Null
}

if (-not (Test-Path $InputFile)) {
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

$proc = Start-Process -FilePath $s.ffmpegPath -ArgumentList $ffArgs -Wait -PassThru -WindowStyle Hidden

if ($proc.ExitCode -ne 0 -or -not (Test-Path $outPath)) {
    Show-Error "Compression failed for:`n$($file.Name)`n`nEncoder tried: $encoderName`nCheck that ffmpeg is working correctly."
    exit 1
}

$newSize   = (Get-Item $outPath).Length
$reduction = [math]::Round((1 - $newSize / $originalSize) * 100)
$origMB    = [math]::Round($originalSize / 1MB, 1)
$newMB     = [math]::Round($newSize / 1MB, 1)

if ($s.showSummary) {
    $msg = "Compression complete.`n`nFile: $($file.Name)`nOriginal:   $origMB MB`nCompressed: $newMB MB`nReduced by: $reduction%`nEncoder:    $encoderName"
    [System.Windows.Forms.MessageBox]::Show($msg, "AVDownsize Complete", `
        [System.Windows.Forms.MessageBoxButtons]::OK, `
        [System.Windows.Forms.MessageBoxIcon]::Information, `
        [System.Windows.Forms.MessageBoxDefaultButton]::Button1, `
        [System.Windows.Forms.MessageBoxOptions]::DefaultDesktopOnly) | Out-Null
}

if ($s.deleteOriginal) {
    Remove-Item $InputFile -Force
}
