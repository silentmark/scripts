param(
    [Parameter(Mandatory = $true)] [string]$DomainName,
    [Parameter(Mandatory = $true)] [string]$AdminPassword
)

$SqlDownloadUrl = "https://go.microsoft.com/fwlink/?linkid=866662"  # SQL Server 2022 Developer ISO
Invoke-WebRequest -Uri $SqlDownloadUrl -OutFile "C:\SQL2022.iso"

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
Mount-DiskImage -ImagePath "C:\SQL2022.iso"

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