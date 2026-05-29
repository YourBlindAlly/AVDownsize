param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptDir      = $PSScriptRoot
$settingsPath   = Join-Path $env:APPDATA "AVDownsize\settings.json"
$compressScript = Join-Path $scriptDir "compress.ps1"
$settingsScript = Join-Path $scriptDir "settings.ps1"

function Load-Settings {
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
        return $s
    }
    return [PSCustomObject]$defaults
}

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

# --- Build chooser form ---

$form = New-Object System.Windows.Forms.Form
$form.Text = "AVDownsize"
$form.Size = New-Object System.Drawing.Size(380, 275)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$fileName = Split-Path $InputFile -Leaf
if ($fileName.Length -gt 45) { $fileName = $fileName.Substring(0, 42) + "..." }

$lblFile = New-Object System.Windows.Forms.Label
$lblFile.Text = "File: $fileName"
$lblFile.Location = New-Object System.Drawing.Point(20, 18)
$lblFile.Size = New-Object System.Drawing.Size(340, 22)
$form.Controls.Add($lblFile)

$sep = New-Object System.Windows.Forms.Label
$sep.BorderStyle = "Fixed3D"
$sep.Location = New-Object System.Drawing.Point(20, 46)
$sep.Size = New-Object System.Drawing.Size(330, 2)
$form.Controls.Add($sep)

$options = @(
    @{ label = "Auto Compress (Recommended)";          mode = "auto" }
    @{ label = "Compress Smaller (more aggressive)";   mode = "smaller" }
    @{ label = "Compress High Quality (conservative)"; mode = "quality" }
)

$radios = @()
$y = 58
foreach ($opt in $options) {
    $rb = New-Object System.Windows.Forms.RadioButton
    $rb.Text = $opt.label
    $rb.Tag  = $opt.mode
    $rb.Location = New-Object System.Drawing.Point(30, $y)
    $rb.Size = New-Object System.Drawing.Size(320, 24)
    $rb.Checked = ($opt.mode -eq "auto")
    $form.Controls.Add($rb)
    $radios += $rb
    $y += 30
}

# Warning label shown only when silent mode is active (showSummary = false)
$lblWarn = New-Object System.Windows.Forms.Label
$lblWarn.ForeColor = [System.Drawing.Color]::DarkRed
$lblWarn.Location = New-Object System.Drawing.Point(20, $y + 4)
$lblWarn.Size = New-Object System.Drawing.Size(340, 32)
$form.Controls.Add($lblWarn)

$btnY = $y + 44

$btnSettings = New-Object System.Windows.Forms.Button
$btnSettings.Text = "Settings"
$btnSettings.Location = New-Object System.Drawing.Point(20, $btnY)
$btnSettings.Size = New-Object System.Drawing.Size(80, 28)
$btnSettings.Add_Click({
    & powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -File $settingsScript
    $reloaded = Load-Settings
    $lblWarn.Text = if (-not $reloaded.showSummary) {
        "Silent mode on: no status will be shown after OK."
    } else { "" }
})
$form.Controls.Add($btnSettings)

$btnOK = New-Object System.Windows.Forms.Button
$btnOK.Text = "OK"
$btnOK.DialogResult = "OK"
$btnOK.Location = New-Object System.Drawing.Point(190, $btnY)
$btnOK.Size = New-Object System.Drawing.Size(80, 28)
$form.Controls.Add($btnOK)
$form.AcceptButton = $btnOK

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancel"
$btnCancel.DialogResult = "Cancel"
$btnCancel.Location = New-Object System.Drawing.Point(280, $btnY)
$btnCancel.Size = New-Object System.Drawing.Size(80, 28)
$form.Controls.Add($btnCancel)
$form.CancelButton = $btnCancel

# Apply initial warning state before showing
$s = Load-Settings
$lblWarn.Text = if (-not $s.showSummary) { "Silent mode on: no status will be shown after OK." } else { "" }

if ($form.ShowDialog() -ne "OK") { exit }

# Re-read settings in case they were changed via the Settings button
$s = Load-Settings
$mode = ($radios | Where-Object { $_.Checked } | Select-Object -First 1).Tag
$form.Hide()

# --- Silent mode: run blocking with no UI, then exit ---
if (-not $s.showSummary) {
    & $compressScript -InputFile $InputFile -Mode $mode -PassThru | Out-Null
    exit
}

# --- Summary mode: show "please wait" while a runspace does the work ---

$waitForm = New-Object System.Windows.Forms.Form
$waitForm.Text = "AVDownsize"
$waitForm.Size = New-Object System.Drawing.Size(300, 110)
$waitForm.StartPosition = "CenterScreen"
$waitForm.FormBorderStyle = "FixedDialog"
$waitForm.MaximizeBox = $false
$waitForm.MinimizeBox = $false
$waitForm.ControlBox = $false
$waitForm.TopMost = $true

# ReadOnly TextBox instead of a Label so screen readers announce it on focus
$txtWait = New-Object System.Windows.Forms.TextBox
$txtWait.Text = "Compressing, please wait..."
$txtWait.Location = New-Object System.Drawing.Point(20, 32)
$txtWait.Size = New-Object System.Drawing.Size(255, 22)
$txtWait.ReadOnly = $true
$txtWait.BorderStyle = "None"
$txtWait.BackColor = $waitForm.BackColor
$txtWait.TabStop = $true
$waitForm.Controls.Add($txtWait)
$waitForm.ActiveControl = $txtWait

# Launch compression in a background runspace so the wait form stays responsive
$rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
$rs.Open()
$ps = [PowerShell]::Create()
$ps.Runspace = $rs
[void]$ps.AddCommand($compressScript)
[void]$ps.AddParameter('InputFile', $InputFile)
[void]$ps.AddParameter('Mode', $mode)
[void]$ps.AddParameter('PassThru', $true)
$handle = $ps.BeginInvoke()

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 500
$timer.Add_Tick({
    if (-not $handle.IsCompleted) { return }

    $timer.Stop()

    try { $results = $ps.EndInvoke($handle) } catch { $results = @() }
    $ps.Dispose()
    $rs.Dispose()

    $waitForm.Hide()

    $result = if ($results.Count -gt 0) { $results[0] } else { $null }

    if ($null -eq $result -or -not $result.Success) {
        $errText = if ($result -and $result.Error) { $result.Error } else { "Unknown error during compression." }
        Show-Notice "AVDownsize Error" $errText
    } else {
        $msg = "File: $($result.FileName)`nOriginal:   $($result.OrigMB) MB`nCompressed: $($result.NewMB) MB`nReduced by: $($result.Reduction)%`nEncoder:    $($result.EncoderName)"
        Show-Notice "AVDownsize Complete" $msg
    }

    [System.Windows.Forms.Application]::Exit()
})
$timer.Start()

[System.Windows.Forms.Application]::Run($waitForm)
