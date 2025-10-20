# ============================
# File: AD-Forest.ps1
# ============================

param(
    [Parameter(Mandatory = $true)] [string]$DomainName,
    [Parameter(Mandatory = $true)] [string]$AdminPassword
)

Write-Host "=== Starting Active Directory Forest setup for $DomainName ==="

$SecurePassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force

# Install AD DS Role
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

# Promote to Domain Controller
Install-ADDSForest `
    -DomainName $DomainName `
    -SafeModeAdministratorPassword $SecurePassword `
    -InstallDNS:$true `
    -Force:$true

Write-Host "Active Directory installation initiated. Registering Post-Setup Task..."
