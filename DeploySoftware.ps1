<#
.SYNOPSIS
Automated deployment script with robust error handling.
Deploys or uninstalls one or more installers on multiple remote computers.
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Install", "Uninstall")]
    [string]$Mode,

    [Parameter(Mandatory = $false)]
    [string]$InstallerPaths,  # semicolon-separated (paths or product names)

    [Parameter(Mandatory = $true)]
    [string[]]$Computers
)

# --- App root ---
function Get-AppRoot {
    if ($PSScriptRoot) { return $PSScriptRoot }
    if ($MyInvocation.MyCommand.Path) { return Split-Path -Parent $MyInvocation.MyCommand.Path }
    try { return Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) }
    catch { return (Get-Location).Path }
}
$AppRoot = Get-AppRoot

$CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$Timestamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
$LogFolder   = Join-Path $AppRoot 'logs'
$LogFile     = Join-Path $LogFolder "DeployLog_$Timestamp.csv"

if (-not (Test-Path $LogFolder)) { New-Item -Path $LogFolder -ItemType Directory | Out-Null }
"Computer,Product,Installer,Status,Time,User" | Out-File -FilePath $LogFile -Encoding UTF8

try {
    if (-not [System.Diagnostics.EventLog]::SourceExists("SoftwareDeploymentTool")) {
        New-EventLog -LogName Application -Source "SoftwareDeploymentTool"
    }
} catch {}

Write-Host "==========================" -ForegroundColor Yellow
Write-Host "Deployment Script Started" -ForegroundColor Yellow
Write-Host "Timestamp: $(Get-Date)"
Write-Host "Mode: $Mode"
Write-Host "==========================" -ForegroundColor Yellow

$ErrorOccurred = $false
$InstallerPathArray = @(); if ($InstallerPaths) { $InstallerPathArray = $InstallerPaths -split ";" }

foreach ($Computer in $Computers) {
    $TimeNow = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "`n[$Computer] Processing..." -ForegroundColor Cyan

    try {
        foreach ($Entry in $InstallerPathArray) {
            if ([string]::IsNullOrWhiteSpace($Entry)) { continue }

            if (Test-Path $Entry) {
                $InstallerPath = $Entry
                $InstallerFile = [IO.Path]::GetFileName($InstallerPath)
                $InstallerExt  = [IO.Path]::GetExtension($InstallerPath).ToLowerInvariant()
                $ProductLabel  = [IO.Path]::GetFileNameWithoutExtension($InstallerFile)
            } else {
                $InstallerPath = $null
                $InstallerFile = "N/A"
                $InstallerExt  = ""
                $ProductLabel  = $Entry.Trim()
            }

            # --- Detect installed app (returns registry key path for verification) ---
            $CheckScript = {
                param($ProductLabel)
                $paths = @(
                    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
                    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
                    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
                )
                foreach ($path in $paths) {
                    Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
                        Where-Object {
                            $_.DisplayName -and
                            ($_.DisplayName -replace '\s','') -like ("*" + ($ProductLabel -replace '\s','') + "*")
                        } |
                        ForEach-Object {
                            $regPath = 'Registry::' + (($_.PSPath -split '::')[-1])
                            return @{
                                Installed       = $true
                                UninstallString = $_.UninstallString
                                DisplayName     = $_.DisplayName
                                RegKeyPath      = $regPath
                                KeyName         = $_.PSChildName
                            }
                        }
                }
                return @{ Installed = $false }
            }

            $Result = if ($Computer -eq "localhost") { & $CheckScript $ProductLabel }
                      else { Invoke-Command -ComputerName $Computer -ScriptBlock $CheckScript -ArgumentList $ProductLabel }

            if ($Mode -eq "Install") {
                if ($Result.Installed) {
                    Write-Host "[$Computer] Already installed: $Result.DisplayName"
                    Add-Content -Path $LogFile -Value "$Computer,$ProductLabel,$InstallerFile,Already Installed,$TimeNow,$CurrentUser"
                    continue
                }

                if (-not $InstallerPath) { throw "Installer path not provided for product '$ProductLabel'." }

                if ($Computer -ne "localhost") {
                    Invoke-Command -ComputerName $Computer -ScriptBlock { New-Item "C:\Temp" -ItemType Directory -Force | Out-Null }
                    Copy-Item -Path $InstallerPath -Destination "\\$Computer\C$\Temp\$InstallerFile" -Force
                } else {
                    New-Item "C:\Temp" -ItemType Directory -Force | Out-Null
                    Copy-Item -Path $InstallerPath -Destination "C:\Temp\$InstallerFile" -Force
                }

                Write-Host "[$Computer] Installing: $InstallerFile"
                $InstallScript = {
                    param($InstallerFile, $InstallerExt)
                    if ($InstallerExt -eq ".msi") {
                        $p = Start-Process "msiexec.exe" "/i C:\Temp\$InstallerFile /qn /norestart" -Wait -PassThru
                        if ($p.ExitCode -notin 0,3010) { throw "Installer exit code $($p.ExitCode)" }
                    } elseif ($InstallerExt -eq ".exe") {
                        $p = Start-Process "C:\Temp\$InstallerFile" "/S" -Wait -PassThru
                        if ($p.ExitCode -ne 0) { throw "Installer exit code $($p.ExitCode)" }
                    } else {
                        throw "Unsupported installer extension: $InstallerExt"
                    }
                }
                if ($Computer -ne "localhost") {
                    Invoke-Command -ComputerName $Computer -ScriptBlock $InstallScript -ArgumentList $InstallerFile, $InstallerExt
                } else {
                    & $InstallScript $InstallerFile $InstallerExt
                }

                Add-Content -Path $LogFile -Value "$Computer,$ProductLabel,$InstallerFile,Installed,$TimeNow,$CurrentUser"
                Write-EventLog -LogName Application -Source "SoftwareDeploymentTool" -EntryType Information -EventID 1001 -Message "[$Computer] Installed $InstallerFile successfully."
                Write-Host "[$Computer] Installed successfully: $InstallerFile" -ForegroundColor Green
            }
            elseif ($Mode -eq "Uninstall") {
                if (-not $Result.Installed) {
                    Write-Host "[$Computer] Not installed: $ProductLabel"
                    Add-Content -Path $LogFile -Value "$Computer,$ProductLabel,N/A,Not Installed,$TimeNow,$CurrentUser"
                    continue
                }

                $UninstallStr = $Result.UninstallString
                Write-Host "[$Computer] Uninstalling: $Result.DisplayName"

                $UninstallScript = {
                    param($UninstallStr)
                    if ($UninstallStr -match '(?i)msiexec') {
                        $guid = ($UninstallStr -replace '.*\{','{' -replace '\}.*','}')
                        if (-not $guid) { throw "Unable to parse product code from: $UninstallStr" }
                        $p = Start-Process "msiexec.exe" "/x $guid /qn /norestart" -Wait -PassThru
                        if ($p.ExitCode -notin 0,3010,1605) { throw "Uninstaller exit code $($p.ExitCode)" } # 1605 = already uninstalled
                    } else {
                        $exe = $null; $args = ''
                        if ($UninstallStr.StartsWith('"')) {
                            $m = [regex]::Match($UninstallStr, '^"([^"]+)"\s*(.*)$')
                            if ($m.Success) { $exe = $m.Groups[1].Value; $args = $m.Groups[2].Value }
                        } else {
                            $parts = $UninstallStr -split '\s+', 2
                            $exe = $parts[0]; if ($parts.Count -gt 1) { $args = $parts[1] }
                        }
                        if (-not $exe) { throw "Uninstall string parse failed: $UninstallStr" }
                        if ($args -notmatch '(?i)(/S|/silent|/quiet|/verysilent|/qn)') {
                            if ($exe -match '(?i)unins.*\.exe') { $args = "$args /VERYSILENT /SUPPRESSMSGBOXES /NORESTART".Trim() }
                            else { $args = "$args /S".Trim() }
                        }
                        $p = Start-Process -FilePath $exe -ArgumentList $args -Wait -PassThru
                        if ($p.ExitCode -notin 0,3010,1605) { throw "Uninstaller exit code $($p.ExitCode)" }
                    }
                }

                if ($Computer -ne "localhost") {
                    Invoke-Command -ComputerName $Computer -ScriptBlock $UninstallScript -ArgumentList $UninstallStr
                    $keyStillThere = Invoke-Command -ComputerName $Computer -ScriptBlock { param($p) Test-Path -LiteralPath $p } -ArgumentList $Result.RegKeyPath
                } else {
                    & $UninstallScript $UninstallStr
                    $keyStillThere = Test-Path -LiteralPath $Result.RegKeyPath
                }

                if ($keyStillThere) {
                    Write-Host "[$Computer] WARNING: Uninstall command completed, but registry key still present: $($Result.RegKeyPath)"
                    Add-Content -Path $LogFile -Value "$Computer,$ProductLabel,N/A,Error: Uninstall verification failed,$TimeNow,$CurrentUser"
                    try { Write-EventLog -LogName Application -Source "SoftwareDeploymentTool" -EntryType Warning -EventID 1003 -Message "[$Computer] Uninstall verification failed for $($Result.DisplayName)." } catch {}
                    $ErrorOccurred = $true
                } else {
                    Add-Content -Path $LogFile -Value "$Computer,$ProductLabel,N/A,Uninstalled,$TimeNow,$CurrentUser"
                    try { Write-EventLog -LogName Application -Source "SoftwareDeploymentTool" -EntryType Information -EventID 1002 -Message "[$Computer] Uninstalled $($Result.DisplayName) successfully." } catch {}
                    Write-Host "[$Computer] Uninstalled successfully." -ForegroundColor Green
                }
            }
        }

        if ($Mode -eq "Uninstall" -and $InstallerPathArray.Count -eq 0) {
            Write-Host "[$Computer] No products specified to uninstall."
        }

    } catch {
        $ErrorOccurred = $true
        $errMsg = $_.Exception.Message
        Write-Host "[$Computer] ERROR: $errMsg" -ForegroundColor Red
        Add-Content -Path $LogFile -Value "$Computer,N/A,N/A,Error: $errMsg,$TimeNow,$CurrentUser"
        try { Write-EventLog -LogName Application -Source "SoftwareDeploymentTool" -EntryType Error -EventID 9999 -Message "[$Computer] Deployment error: $errMsg" } catch {}
    }
}

# === Generate HTML Report Automatically ===
Write-Host "`nGenerating HTML report..."
$ReportScript = Join-Path $AppRoot 'GenerateReport.ps1'
try { & $ReportScript; Write-Host "HTML report generated successfully." }
catch { Write-Host "WARNING: Report generation failed: $($_.Exception.Message)" }

Write-Host "`n=== Deployment Summary ==="
Get-Content $LogFile | ForEach-Object { Write-Host $_ }

if ($ErrorOccurred) { exit 1 } else { exit 0 }
