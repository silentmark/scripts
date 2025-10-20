param(
    [Parameter(Mandatory=$true)]
    [string]$DomainName = "kembrowski.ovh",
    [Parameter(Mandatory=$true)]
    [string]$AdminPassword = "P@ssw0rd1234!"  # Default password, change as needed
)

# You may want to set this to your domain admin username used in setup-ad.ps1
$DomainAdminUser = "contosoadmin"

# Convert plain text password to secure string
$SecurePassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force

# Create domain credential
$Credential = New-Object System.Management.Automation.PSCredential ("$DomainAdminUser", $SecurePassword)

Add-Computer -DomainName $DomainName -Credential $Credential -Force -ErrorAction Stop
Write-Host "Successfully joined $env:COMPUTERNAME to domain $DomainName."
# Optionally restart to complete joining
Restart-Computer -Force