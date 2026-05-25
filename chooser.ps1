param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptDir = $PSScriptRoot

$form = New-Object System.Windows.Forms.Form
$form.Text = "AVDownsize"
$form.Size = New-Object System.Drawing.Size(380, 270)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Show file name, truncated if long
$fileName = Split-Path $InputFile -Leaf
if ($fileName.Length -gt 45) { $fileName = $fileName.Substring(0, 42) + "..." }

$lblFile = New-Object System.Windows.Forms.Label
$lblFile.Text = "File: $fileName"
$lblFile.Location = New-Object System.Drawing.Point(20, 18)
$lblFile.Size = New-Object System.Drawing.Size(340, 22)
$form.Controls.Add($lblFile)

# Separator line
$sep = New-Object System.Windows.Forms.Label
$sep.BorderStyle = "Fixed3D"
$sep.Location = New-Object System.Drawing.Point(20, 46)
$sep.Size = New-Object System.Drawing.Size(330, 2)
$form.Controls.Add($sep)

# Radio buttons
$options = @(
    @{ label = "Auto Compress (Recommended)"; mode = "auto" }
    @{ label = "Compress Smaller (more aggressive)";  mode = "smaller" }
    @{ label = "Compress High Quality (conservative)"; mode = "quality" }
    @{ label = "Settings"; mode = "settings" }
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

# Buttons
$btnOK = New-Object System.Windows.Forms.Button
$btnOK.Text = "OK"
$btnOK.DialogResult = "OK"
$btnOK.Location = New-Object System.Drawing.Point(190, $y + 8)
$btnOK.Size = New-Object System.Drawing.Size(80, 28)
$form.Controls.Add($btnOK)
$form.AcceptButton = $btnOK

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancel"
$btnCancel.DialogResult = "Cancel"
$btnCancel.Location = New-Object System.Drawing.Point(280, $y + 8)
$btnCancel.Size = New-Object System.Drawing.Size(80, 28)
$form.Controls.Add($btnCancel)
$form.CancelButton = $btnCancel

if ($form.ShowDialog() -ne "OK") { exit }

$mode = ($radios | Where-Object { $_.Checked } | Select-Object -First 1).Tag

$ps = "powershell.exe"
$bypass = "-ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive"

if ($mode -eq "settings") {
    Start-Process $ps -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptDir\settings.ps1`""
} else {
    Start-Process $ps -ArgumentList "$bypass -File `"$scriptDir\compress.ps1`" -InputFile `"$InputFile`" -Mode $mode"
}
