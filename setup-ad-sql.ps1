param(
    [Parameter(Mandatory=$true)] [string]$DomainName,
    [Parameter(Mandatory=$true)] [string]$AdminPassword
)


# After reboot, re-run post configuration
$scriptBlock = {
    Import-Module ActiveDirectory

    $password = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
    $users = @(
        @{Name="John Doe";Sam="jdoe"},
        @{Name="Alice Smith";Sam="asmith"},
        @{Name="Robert Brown";Sam="rbrown"},
        @{Name="Emma White";Sam="ewhite"},
        @{Name="Michael Green";Sam="mgreen"}
    )

    foreach ($u in $users) {
        New-ADUser -Name $u.Name -GivenName $u.Name.Split(' ')[0] -Surname $u.Name.Split(' ')[1] `
            -SamAccountName $u.Sam -AccountPassword $password -Enabled $true -PasswordNeverExpires $true
    }


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

    Write-Host "Configuring SQL to start automatically..."
    Set-Service -Name MSSQLSERVER -StartupType Automatic
    Start-Service -Name MSSQLSERVER

    Write-Host "===== Setup Complete ====="
}

$taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -Command &{$(&{$scriptBlock})}"
$taskTrigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -Action $taskAction -Trigger $taskTrigger -TaskName "ADPostConfig" -Description "Finish AD and SQL setup" -User "SYSTEM" -RunLevel Highest

Write-Host "===== Starting AD + SQL setup ====="

Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

$SecurePassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force

Install-ADDSForest `
  -DomainName $DomainName `
  -SafeModeAdministratorPassword $SecurePassword `
  -InstallDns:$true `
  -Force:$true

Write-Host "AD DS installation complete, rebooting..."
