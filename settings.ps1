Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$settingsPath = Join-Path $env:APPDATA "AVDownsize\settings.json"
$defaults = [PSCustomObject]@{
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
} else {
    $s = $defaults
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "AVDownsize Settings"
$form.Size = New-Object System.Drawing.Size(500, 400)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$labelW  = 160
$inputX  = 180
$inputW  = 290
$y       = 20
$rowH    = 38

function Add-Row($labelText, $top) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $labelText
    $lbl.Location = New-Object System.Drawing.Point(20, ($top + 3))
    $lbl.Size = New-Object System.Drawing.Size($labelW, 20)
    $form.Controls.Add($lbl)
}

# FFmpeg path
Add-Row "FFmpeg path:" $y
$txtFFmpeg = New-Object System.Windows.Forms.TextBox
$txtFFmpeg.Text = $s.ffmpegPath
$txtFFmpeg.Location = New-Object System.Drawing.Point($inputX, $y)
$txtFFmpeg.Size = New-Object System.Drawing.Size($inputW, 23)
$form.Controls.Add($txtFFmpeg)
$y += $rowH

# FFprobe path
Add-Row "FFprobe path:" $y
$txtFFprobe = New-Object System.Windows.Forms.TextBox
$txtFFprobe.Text = $s.ffprobePath
$txtFFprobe.Location = New-Object System.Drawing.Point($inputX, $y)
$txtFFprobe.Size = New-Object System.Drawing.Size($inputW, 23)
$form.Controls.Add($txtFFprobe)
$y += $rowH

# Output folder with Browse button
Add-Row "Output folder:" $y
$txtFolder = New-Object System.Windows.Forms.TextBox
$txtFolder.Text = $s.outputFolder
$txtFolder.Location = New-Object System.Drawing.Point($inputX, $y)
$txtFolder.Size = New-Object System.Drawing.Size(225, 23)
$form.Controls.Add($txtFolder)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Browse"
$btnBrowse.Location = New-Object System.Drawing.Point(410, $y)
$btnBrowse.Size = New-Object System.Drawing.Size(60, 23)
$btnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Select output folder (leave blank to save next to source file)"
    if ($dlg.ShowDialog() -eq "OK") { $txtFolder.Text = $dlg.SelectedPath }
})
$form.Controls.Add($btnBrowse)
$y += $rowH

# Output suffix
Add-Row "Output suffix:" $y
$txtSuffix = New-Object System.Windows.Forms.TextBox
$txtSuffix.Text = $s.outputSuffix
$txtSuffix.Location = New-Object System.Drawing.Point($inputX, $y)
$txtSuffix.Size = New-Object System.Drawing.Size($inputW, 23)
$form.Controls.Add($txtSuffix)
$y += $rowH + 5

# Checkboxes
function Add-Check($labelText, $checked, $top) {
    $c = New-Object System.Windows.Forms.CheckBox
    $c.Text = $labelText
    $c.Checked = $checked
    $c.Location = New-Object System.Drawing.Point($inputX, $top)
    $c.Size = New-Object System.Drawing.Size($inputW, 23)
    $form.Controls.Add($c)
    return $c
}

$chkDelete    = Add-Check "Delete original after compression" $s.deleteOriginal $y; $y += 28
$chkDownscale = Add-Check "Downscale 4K video to 1080p"      $s.downscale4K    $y; $y += 28
$chkSummary   = Add-Check "Show completion summary (uncheck for silent mode)" $s.showSummary $y; $y += 42

# Save / Cancel
$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = "Save"
$btnSave.DialogResult = "OK"
$btnSave.Location = New-Object System.Drawing.Point(285, $y)
$btnSave.Size = New-Object System.Drawing.Size(90, 30)
$form.Controls.Add($btnSave)
$form.AcceptButton = $btnSave

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancel"
$btnCancel.DialogResult = "Cancel"
$btnCancel.Location = New-Object System.Drawing.Point(383, $y)
$btnCancel.Size = New-Object System.Drawing.Size(90, 30)
$form.Controls.Add($btnCancel)
$form.CancelButton = $btnCancel

if ($form.ShowDialog() -eq "OK") {
    $newSettings = @{
        ffmpegPath     = $txtFFmpeg.Text.Trim()
        ffprobePath    = $txtFFprobe.Text.Trim()
        outputFolder   = $txtFolder.Text.Trim()
        deleteOriginal = $chkDelete.Checked
        outputSuffix   = if ($txtSuffix.Text.Trim()) { $txtSuffix.Text.Trim() } else { "_compressed" }
        downscale4K    = $chkDownscale.Checked
        showSummary    = $chkSummary.Checked
    }

    $dir = Split-Path $settingsPath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $newSettings | ConvertTo-Json | Set-Content $settingsPath -Encoding UTF8

    [System.Windows.Forms.MessageBox]::Show("Settings saved.", "AVDownsize", 0, 64) | Out-Null
}
