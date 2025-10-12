Add-Type -AssemblyName System.Windows.Forms

function Get-AppRoot {
    if ($PSScriptRoot) { return $PSScriptRoot }
    if ($MyInvocation.MyCommand.Path) { return Split-Path -Parent $MyInvocation.MyCommand.Path }
    try { return Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) }
    catch { return (Get-Location).Path }
}

# === Get the directory of this script / EXE ===
$ScriptFolder = Get-AppRoot

# === Create Form ===
$form = New-Object System.Windows.Forms.Form
$form.Text = "Automated Software Deployment Tool"
$form.Size = New-Object System.Drawing.Size(700,800)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::WhiteSmoke

# === Title ===
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Software Deployment Tool"
$titleLabel.Font = "Segoe UI,14,style=Bold"
$titleLabel.ForeColor = "SteelBlue"
$titleLabel.AutoSize = $true
$titleLabel.Location = New-Object System.Drawing.Point(20,15)
$form.Controls.Add($titleLabel)

# === Mode ===
$labelMode = New-Object System.Windows.Forms.Label
$labelMode.Text = "Mode:"
$labelMode.Location = New-Object System.Drawing.Point(20,55)
$labelMode.Font = "Segoe UI,10"
$form.Controls.Add($labelMode)

$comboMode = New-Object System.Windows.Forms.ComboBox
$comboMode.Items.AddRange(@("Install","Uninstall"))
$comboMode.SelectedIndex = 0
$comboMode.Location = New-Object System.Drawing.Point(150,52)
$comboMode.Width = 160
$comboMode.Font = "Segoe UI,10"
$form.Controls.Add($comboMode)

# === Installer Files ===
$labelFile = New-Object System.Windows.Forms.Label
$labelFile.Text = "Installer Files:"
$labelFile.Location = New-Object System.Drawing.Point(20,90)
$labelFile.Font = "Segoe UI,10"
$form.Controls.Add($labelFile)

$textFile = New-Object System.Windows.Forms.TextBox
$textFile.Multiline = $true
$textFile.ScrollBars = "Vertical"
$textFile.Location = New-Object System.Drawing.Point(150,88)
$textFile.Size = New-Object System.Drawing.Size(400,60)
$textFile.Font = "Segoe UI,10"
$form.Controls.Add($textFile)

$buttonBrowse = New-Object System.Windows.Forms.Button
$buttonBrowse.Text = "Browse..."
$buttonBrowse.Location = New-Object System.Drawing.Point(560,86)
$buttonBrowse.Font = "Segoe UI,10"
$buttonBrowse.BackColor = "LightSteelBlue"
$buttonBrowse.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "Installer Files (*.msi;*.exe)|*.msi;*.exe"
    $dialog.Multiselect = $true
    if ($dialog.ShowDialog() -eq "OK") {
        $textFile.Lines = $dialog.FileNames
    }
})
$form.Controls.Add($buttonBrowse)

# === Email Recipient ===
$labelEmail = New-Object System.Windows.Forms.Label
$labelEmail.Text = "Notification Email:"
$labelEmail.Location = New-Object System.Drawing.Point(20,160)
$labelEmail.Font = "Segoe UI,10"
$form.Controls.Add($labelEmail)

$textEmail = New-Object System.Windows.Forms.TextBox
$textEmail.Text = ""
$textEmail.Location = New-Object System.Drawing.Point(150,158)
$textEmail.Width = 500
$textEmail.Font = "Segoe UI,10"
$form.Controls.Add($textEmail)

# === Computers ===
$labelComputers = New-Object System.Windows.Forms.Label
$labelComputers.Text = "Target Computers (one per line):"
$labelComputers.Location = New-Object System.Drawing.Point(20,195)
$labelComputers.Font = "Segoe UI,10"
$form.Controls.Add($labelComputers)

$textComputers = New-Object System.Windows.Forms.TextBox
$textComputers.Multiline = $true
$textComputers.ScrollBars = "Vertical"
$textComputers.Text = "localhost"
$textComputers.Location = New-Object System.Drawing.Point(20,215)
$textComputers.Size = New-Object System.Drawing.Size(630,100)
$textComputers.Font = "Segoe UI,10"
$form.Controls.Add($textComputers)

# === Start Button ===
$buttonStart = New-Object System.Windows.Forms.Button
$buttonStart.Text = "Start Deployment"
$buttonStart.Font = "Segoe UI,10,style=Bold"
$buttonStart.BackColor = "SteelBlue"
$buttonStart.ForeColor = "White"
$buttonStart.Width = 220
$buttonStart.Height = 35
$buttonStart.Location = New-Object System.Drawing.Point(150,330)
$form.Controls.Add($buttonStart)

# === Output Log ===
$labelOutput = New-Object System.Windows.Forms.Label
$labelOutput.Text = "Output Log:"
$labelOutput.Location = New-Object System.Drawing.Point(20,380)
$labelOutput.Font = "Segoe UI,10"
$form.Controls.Add($labelOutput)

$textLog = New-Object System.Windows.Forms.TextBox
$textLog.Multiline = $true
$textLog.ScrollBars = "Vertical"
$textLog.ReadOnly = $true
$textLog.BackColor = "White"
$textLog.Location = New-Object System.Drawing.Point(20,400)
$textLog.Size = New-Object System.Drawing.Size(630,320)
$textLog.Font = "Consolas,9"
$form.Controls.Add($textLog)

# === Start Button Logic ===
$buttonStart.Add_Click({
    $buttonStart.Enabled = $false
    $mode = $comboMode.SelectedItem
    $installerPaths = $textFile.Lines | Where-Object { $_.Trim() -ne "" }
    $computers = $textComputers.Lines | Where-Object { $_.Trim() -ne "" }
    $emailRecipient = $textEmail.Text.Trim()

    if ($computers.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please enter at least one computer.","Error")
        $buttonStart.Enabled = $true
        return
    }
    if ($mode -eq "Install" -and $installerPaths.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one installer.","Error")
        $buttonStart.Enabled = $true
        return
    }

    $textLog.Clear()
    $textLog.AppendText("Starting deployment...`r`n")

    $installerArg = ($installerPaths -join ";")
    $deployScript = Join-Path $ScriptFolder "DeploySoftware.ps1"
    $psPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

    try {
        $args = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", $deployScript,
            "-Mode", $mode,
            "-InstallerPaths", $installerArg,
            "-Computers"
        ) + $computers

        $output = & $psPath @args 2>&1
        foreach ($line in $output) {
            $textLog.AppendText( ($line | Out-String) )
        }
    }
    catch {
        $textLog.AppendText(("ERROR during deployment: {0}`r`n" -f $_))
    }

    if ($emailRecipient) {
        $textLog.AppendText("Sending email notification...`r`n")
        try {
            & $psPath -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ScriptFolder "SendDeploymentEmail.ps1") -RecipientEmail $emailRecipient
            $textLog.AppendText("Email sent.`r`n")
        }
        catch {
            $textLog.AppendText(("ERROR sending email: {0}`r`n" -f $_))
        }
    }

    $textLog.AppendText("All tasks completed.`r`n")
    $buttonStart.Enabled = $true
})

$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()
