param location string
param vnetName string = 'myVNet'
param vmsubnetName string = 'myVmSubnet'
param bastionsubnetName string = 'AzureBastionSubnet'
param vmName string = 'myVM'
param vmSize string = 'Standard_D2s_v3'
param adminUsername string
@secure()
param adminPassword string

var vmsubnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, vmsubnetName)
var bastionsubnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, bastionsubnetName)

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    subnets: [
      {
        name: vmsubnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
      {
        name: bastionsubnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
    ]
  }
}

resource publicIP 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'myPublicIP'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'myNIC'
  location: location
  dependsOn: [
    vnet
  ]
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: vmsubnetRef
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
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
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
          enableHotpatching: false
        }
      }
      allowExtensionOperations: true
    }
    securityProfile: {
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
      securityType: 'TrustedLaunch'
    }
    storageProfile: {
      imageReference: {
        publisher: 'microsoftvisualstudio'
        offer: 'visualstudioplustools'
        sku: 'vs-2022-comm-general-win11-m365-gen2'
        version: 'latest'
      }
      osDisk: {
        name: 'osdisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        diskSizeGB: 256
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: 'myBastionHost'
  location: location
  dependsOn: [
    vnet
  ]
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: bastionsubnetRef
          }
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'myNsg'
  location: location
  properties: {
    securityRules: [
    ]
  }
}

resource downloadAndInstall 'Microsoft.Compute/virtualMachines/runCommands@2024-07-01' = {
  parent: vm
  name: 'downloadAndInstall'
  location: resourceGroup().location
  properties: {
    source: {
      script: '''
        $pythonInstaller = "C:\\temp\\python.exe"
        $pythonUrl = "https://www.python.org/ftp/python/3.12.9/python-3.12.9-amd64.exe"

        # Ensure temp directory exists
        if (!(Test-Path "C:\\temp")) {
            New-Item -ItemType Directory -Path "C:\\temp" | Out-Null
        }

        # Download Python installer
        Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller

        # Install Python silently
        Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0" -Wait -NoNewWindow

        # Ensure the PATH environment variable is updated (this is important for subsequent commands)
        $env:Path += ";C:\Program Files\Python312\Scripts;C:\Program Files\Python312"

        $odbcInstaller = "C:\\temp\\mssql.msi"
        $odbcUrl = "https://go.microsoft.com/fwlink/?linkid=2280794"

        # Download ODBC installer
        Invoke-WebRequest -Uri $odbcUrl -OutFile $odbcInstaller

        # Install ODBC silently
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $odbcInstaller /quiet /passive /norestart" -Wait -NoNewWindow

        # Install dbt-core and dbt-fabric
        Start-Process -FilePath "pip" -ArgumentList "install dbt-core" -Wait -NoNewWindow
        Start-Process -FilePath "pip" -ArgumentList "install dbt-fabric" -Wait -NoNewWindow

        # Final pip upgrade (as last step)
        Start-Process -FilePath "python.exe" -ArgumentList "-m pip install --upgrade pip" -Wait -NoNewWindow
      '''
    }
  }
}