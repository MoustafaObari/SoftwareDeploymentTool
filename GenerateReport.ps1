# ----- App root (works for .ps1 or packaged .exe) -----
function Get-AppRoot {
    if ($PSScriptRoot) { return $PSScriptRoot }
    if ($MyInvocation.MyCommand.Path) { return Split-Path -Parent $MyInvocation.MyCommand.Path }
    try { return Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) }
    catch { return (Get-Location).Path }
}
$AppRoot = Get-AppRoot

# === Folders ===
$LogFolder    = Join-Path $AppRoot 'logs'
$ReportFolder = Join-Path $AppRoot 'HTML reports'

# === Get latest CSV log ===
$CsvFile = Get-ChildItem -Path $LogFolder -Filter "DeployLog_*.csv" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if (-not $CsvFile) { Write-Host "No log file found in $LogFolder."; exit 1 }

$CsvData = Import-Csv -Path $CsvFile.FullName -Encoding UTF8

# === Summary counts ===
$SummaryGroups = $CsvData | Group-Object Status

# === Metadata ===
$GeneratedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$CurrentUser   = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$HostMachine   = $env:COMPUTERNAME

# === Pre-content ===
$SummaryHtml = "<ul style='margin:0;padding-left:20px;'>"
foreach ($g in $SummaryGroups) { $SummaryHtml += "<li><strong>$($g.Name)</strong>: $($g.Count)</li>" }
$SummaryHtml += "</ul>"
$PreContent = @"
<h2 style='margin-bottom:4px;'>Deployment Report</h2>
<p style='margin:0;color:#555;'>
Generated on: $GeneratedDate<br>
Run by: $CurrentUser<br>
Host Machine: $HostMachine
</p>
<div style='margin-top:10px;margin-bottom:10px;'>
<strong>Summary:</strong>
$SummaryHtml
</div>
"@

# === Table as fragment ===
$TableFragment = $CsvData | ConvertTo-Html -Fragment -PreContent $PreContent

# === Full page ===
$HtmlPage = @"
<!DOCTYPE html>
<html>
<head>
<meta charset='UTF-8'>
<title>Deployment Report</title>
<style>
body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background:#f4f6f8; color:#333; padding:30px; }
h2 { color:#2d3e50; }
table { border-collapse:collapse; width:100%; margin-top:20px; }
th { background:#0078d4; color:#fff; padding:10px; font-size:14px; text-align:left; }
td { background:#fff; padding:8px; font-size:13px; border-bottom:1px solid #ddd; }
tr:nth-child(even) td { background:#f0f4f8; }
tr:hover td { background:#e2f1fb; }
.status-Installed{color:#2e7d32;font-weight:bold;}
.status-Uninstalled{color:#1976d2;font-weight:bold;}
.status-AlreadyInstalled{color:#f57c00;font-weight:bold;}
.status-NotInstalled{color:#f57c00;font-weight:bold;}
.status-Error{color:#c62828;font-weight:bold;}
</style>
</head>
<body>
$TableFragment
</body>
</html>
"@

# === Status coloring ===
$HtmlPage = $HtmlPage -replace '<td>Installed</td>', '<td class="status-Installed">Installed</td>'
$HtmlPage = $HtmlPage -replace '<td>Uninstalled</td>', '<td class="status-Uninstalled">Uninstalled</td>'
$HtmlPage = $HtmlPage -replace '<td>Already Installed</td>', '<td class="status-AlreadyInstalled">Already Installed</td>'
$HtmlPage = $HtmlPage -replace '<td>Not Installed</td>', '<td class="status-NotInstalled">Not Installed</td>'
$HtmlPage = $HtmlPage -replace '<td>(Error.*?)</td>', '<td class="status-Error">$1</td>'

# === Save ===
if (-not (Test-Path $ReportFolder)) { New-Item -Path $ReportFolder -ItemType Directory | Out-Null }
$FileNameTime = (Get-Date -Format 'yyyyMMdd_HHmmss')
$ReportFile   = Join-Path $ReportFolder "DeployReport_$FileNameTime.html"
$HtmlPage | Out-File -FilePath $ReportFile -Encoding UTF8
Write-Host "HTML report generated: $ReportFile"
