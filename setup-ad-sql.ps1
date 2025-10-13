param(
    [Parameter(Mandatory=$true)] [string]$DomainName,
    [Parameter(Mandatory=$true)] [string]$AdminPassword
)

Write-Host "===== Starting AD + SQL setup ====="

# --- Install AD DS ---
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

$SecurePassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force

# Promote to Domain Controller
Install-ADDSForest `
  -DomainName $DomainName `
  -SafeModeAdministratorPassword $SecurePassword `
  -InstallDns:$true `
  -Force:$true

Write-Host "AD DS installation complete, rebooting..."
Restart-Computer -Force
Start-Sleep -Seconds 120

# --- Wait for reboot and continue (script resumes manually if re-run) ---
# After reboot, AD DS is installed. Now install SQL.

# --- Install SQL Server Developer Edition ---
$ErrorActionPreference = 'Stop'

Write-Host "Installing SQL Server Developer Edition..."

$SqlDownloadUrl = "https://go.microsoft.com/fwlink/?linkid=866662"  # SQL Server 2022 Developer ISO
$SqlInstaller = "C:\SQL2022.iso"

Invoke-WebRequest -Uri $SqlDownloadUrl -OutFile $SqlInstaller
Mount-DiskImage -ImagePath $SqlInstaller
$mount = Get-Volume | Where-Object { $_.FileSystemLabel -like "SQLSERVER*" } | Select-Object -First 1

$driveLetter = $mount.DriveLetter
$setupPath = "$($driveLetter):\setup.exe"

Write-Host "Running SQL setup from $setupPath"

Start-Process -FilePath $setupPath -Wait -ArgumentList `
    "/Q /ACTION=Install /IACCEPTSQLSERVERLICENSETERMS /FEATURES=SQLEngine /INSTANCENAME=MSSQLSERVER /SECURITYMODE=SQL /SAPWD=$AdminPassword /SQLSVCACCOUNT='NT AUTHORITY\NETWORK SERVICE' /SQLSYSADMINACCOUNTS='Administrator'"

Write-Host "SQL installation complete."

# --- Post-configuration ---
Write-Host "Configuring SQL to start automatically..."
Set-Service -Name MSSQLSERVER -StartupType Automatic
Start-Service -Name MSSQLSERVER

Write-Host "===== Setup Complete ====="
