param location string = resourceGroup().location
param adminUsername string = 'contosoadmin'
@secure()
param adminPassword string

param vmName string = 'ad-dev-contoso'
param domainName string = 'contoso.local'
param vmSize string = 'Standard_B2ms'

var vnetName = 'vnet-dev-contoso'
var subnetName = 'subnet-dev-contoso'
var nsgName = '${vmName}-nsg'
var nicName = '${vmName}-nic'
var pipName = '${vmName}-pip'
var identityName = '${vmName}-uami'
var resourceGroupName = resourceGroup().name

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

resource rgRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, uami.id, 'contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')  // Owner
    principalId: uami.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'RDP'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: pipName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          publicIPAddress: {
            id: pip.id
          }
        }
      }
    ]
  }
}

// VM
resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-Datacenter'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

// Run setup script on first boot
resource setupExtensionForest 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  parent: vm
  name: 'SetupExtensionForest'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/silentmark/scripts/refs/heads/main/setup-ad.ps1'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File setup-ad.ps1 -DomainName ${domainName} -AdminPassword "${adminPassword}"'
    }
  }
}

resource waitForVM 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'waitForVM'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uami.id}': {}
    }
  }
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '11.0'
    scriptContent: '$retry = 0; do { $vm = Get-AzVM -ResourceGroupName "${resourceGroupName}" -Name "${vmName}" -Status; $state = $vm.Statuses | Where-Object { $_.Code -like "PowerState/*" } | Select-Object -ExpandProperty DisplayStatus; Write-Host "VM state: $state"; if ($state -eq "VM running") { Write-Host "VM is running, proceeding..."; exit 0 } Start-Sleep -Seconds 30; $retry++; } while ($retry -lt 20); throw "VM did not reach running state within the expected time.";'
    timeout: 'PT30M'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
}


resource sqlSetup 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'sqlSetup'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uami.id}': {}
    }
  }
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '11.0'
    scriptContent: 'Write-Host "Executing SQL setup inside VM ${vmName}..."; $securePassword = ConvertTo-SecureString "${adminPassword}" -AsPlainText -Force; $cred = New-Object System.Management.Automation.PSCredential ("${adminUsername}", $securePassword); $scriptUrl = "https://raw.githubusercontent.com/silentmark/scripts/refs/heads/main/setup-sql.ps1";$localScript = "setup-sql.ps1"; Invoke-WebRequest -Uri $scriptUrl -OutFile $localScript; Invoke-AzVMRunCommand -ResourceGroupName "${resourceGroupName}" -VMName "${vmName}" -CommandId \'RunPowerShellScript\' -ScriptPath $localScript -Parameter @{"AdminPassword"="${adminPassword}"};Write-Host "SQL Setup script executed inside VM."'
    timeout: 'PT60M'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
  dependsOn: [
    waitForVM
  ]
}
