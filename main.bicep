param location string = resourceGroup().location
param adminUsername string = 'contosoadmin'
@secure()
param adminPassword string

param domainName string = 'kembrowski.ovh'
param vmSize string = 'Standard_B2ms'
param adVmName string = 'dev-ad-kem'
param memberVmNames array = [
  'dev-1-kem'
  'dev-2-kem'
]

var vnetName = 'vnet-dev-kem'
var subnetName = 'subnet-dev-kem'
var resourceGroupName = resourceGroup().name
var dcIp = '10.0.0.4'

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'ad-vms-uami'
  location: location
}

resource rgRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, uami.id, 'contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
    principalId: uami.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: 'ad-vms-nsg'
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
      {
        name: 'DomainDNS'
        properties: {
          priority: 1100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '53'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DomainDNSUDP'
        properties: {
          priority: 1110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Udp'
          sourcePortRange: '*'
          destinationPortRange: '53'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DomainKerberos'
        properties: {
          priority: 1120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '88'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DomainKerberosUDP'
        properties: {
          priority: 1130
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Udp'
          sourcePortRange: '*'
          destinationPortRange: '88'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DomainLDAP'
        properties: {
          priority: 1140
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '389'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DomainLDAPUDP'
        properties: {
          priority: 1150
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Udp'
          sourcePortRange: '*'
          destinationPortRange: '389'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DomainSMB'
        properties: {
          priority: 1160
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '445'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DomainRPC'
        properties: {
          priority: 1170
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '135'
          sourceAddressPrefix: 'VirtualNetwork'
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
    dhcpOptions: {
      dnsServers: [
        '10.0.0.4'
        '8.8.8.8'
      ]
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


resource adPip 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: '${adVmName}-pip'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource adNic 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: '${adVmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: dcIp
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          publicIPAddress: {
            id: adPip.id
          }
        }
      }
    ]
  }
}

resource adVm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: adVmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: adVmName
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
          id: adNic.id
        }
      ]
    }
  }
}


resource setupDomainController 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  parent: adVm
  name: 'SetupDomainController'
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
    scriptContent: '$retry = 0; do { $vm = Get-AzVM -ResourceGroupName "${resourceGroupName}" -Name "${adVmName}" -Status; $state = $vm.Statuses | Where-Object { $_.Code -like "PowerState/*" } | Select-Object -ExpandProperty DisplayStatus; Write-Host "VM state: $state"; if ($state -eq "VM running") { Write-Host "VM is running, proceeding..."; exit 0 } Start-Sleep -Seconds 30; $retry++; } while ($retry -lt 20); throw "VM did not reach running state within the expected time.";'
    timeout: 'PT30M'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
  dependsOn: [
    setupDomainController
  ]
}


resource pips 'Microsoft.Network/publicIPAddresses@2023-04-01' = [for vmName in memberVmNames: {
  name: '${vmName}-pip'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
  dependsOn: [
    waitForVM
    adPip
  ]
}]

resource nics 'Microsoft.Network/networkInterfaces@2023-04-01' = [for (vmName, i) in memberVmNames: {
  name: '${vmName}-nic'
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
            id: pips[i].id
          }
        }
      }
    ]
  }
  dependsOn: [
    waitForVM
    adNic
  ]
}]

resource vms 'Microsoft.Compute/virtualMachines@2023-03-01' = [for (vmName, i) in memberVmNames: {
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
          id: nics[i].id
        }
      ]
    }
  }
  dependsOn: [
    waitForVM
    adVm
  ]
}]

resource joinDomainExtensions 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = [for (vmName, i) in memberVmNames: {
  parent: vms[i]
  name: 'JoinDomain'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/silentmark/scripts/refs/heads/main/join-domain.ps1'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File join-domain.ps1 -DomainName ${domainName} -AdminPassword "${adminPassword}"'
    }
  }
  dependsOn: [
    waitForVM
    vms
  ]
}]
