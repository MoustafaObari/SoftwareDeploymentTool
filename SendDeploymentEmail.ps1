param(
    [Parameter(Mandatory = $true)]
    [string]$RecipientEmail
)

# --- SMTP ---
$smtpServer = "smtp.gmail.com"
$smtpPort   = 587
$smtpUser   = ""      # e.g. "you@gmail.com"
$smtpPass   = ""      # Gmail App Password

if (-not $smtpUser -and $env:SMTP_USER) { $smtpUser = $env:SMTP_USER }
if (-not $smtpPass -and $env:SMTP_PASS) { $smtpPass = $env:SMTP_PASS }

try { [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 } catch {}

# --- App root ---
function Get-AppRoot {
    if ($PSScriptRoot) { return $PSScriptRoot }
    if ($MyInvocation.MyCommand.Path) { return Split-Path -Parent $MyInvocation.MyCommand.Path }
    try { return Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) }
    catch { return (Get-Location).Path }
}
$AppRoot    = Get-AppRoot
$BaseFolder = $AppRoot

# --- Locate latest artifacts ---
$Log  = Get-ChildItem -Path (Join-Path $BaseFolder "logs") -Filter "DeployLog_*.csv" |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
$Html = Get-ChildItem -Path (Join-Path $BaseFolder "HTML reports") -Filter "DeployReport_*.html" |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $Log)  { Write-Host "No log file found. Email not sent.";  exit 1 }
if (-not $Html) { Write-Host "No HTML report found. Email not sent."; exit 1 }

# --- Plaintext summary from CSV ---
$CsvData = Import-Csv -Path $Log.FullName -Encoding UTF8
$DeployedSummary = if (-not $CsvData -or $CsvData.Count -eq 0) {
    "No details recorded."
} else {
    ($CsvData | ForEach-Object { "- {0} on {1} ({2}) at {3}" -f $_.Product, $_.Computer, $_.Status, $_.Time }) -join "`r`n"
}

# --- Compose email ---
$mail = New-Object System.Net.Mail.MailMessage
$mail.From = New-Object System.Net.Mail.MailAddress($smtpUser)
$mail.To.Add($RecipientEmail)
$mail.Subject = "Deployment Report - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$mail.Body = @"
Hello,

The deployment completed.

Details:
$DeployedSummary

Attached are:
- The deployment log file
- The HTML report

Regards,
Automated Deployment Tool
"@
$mail.IsBodyHtml = $false

# --- Attach and send ---
try {
    $mail.Attachments.Add([System.Net.Mail.Attachment]::new($Log.FullName))  | Out-Null
    $mail.Attachments.Add([System.Net.Mail.Attachment]::new($Html.FullName)) | Out-Null
} catch { Write-Host "ERROR attaching files: $_"; $mail.Dispose(); exit 1 }

$smtp = New-Object System.Net.Mail.SmtpClient($smtpServer, $smtpPort)
$smtp.EnableSsl = $true
$smtp.Credentials = New-Object System.Net.NetworkCredential($smtpUser, $smtpPass)

try { $smtp.Send($mail); Write-Host "Email sent to $RecipientEmail."; exit 0 }
catch { Write-Host "ERROR sending email: $_"; exit 1 }
finally { $mail.Dispose() }
