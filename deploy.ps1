param(
    [string]$rgname = 'dbt-rg',             # Default resource group name
    [string]$vmName = 'myVM',               # Default VM name
    [string]$vmSize = 'Standard_D2s_v3',    # Default VM Size
    [string]$location = 'swedencentral',    # Region
    [string]$adminUsername = 'localadmin'   # Username
)

$adminPassword = Read-Host -Prompt 'Input the user password' -AsSecureString
#Deploy ResourceGroup
Write-Output -InputObject "Initiating ResourceGroup...$(get-date)"
New-AzResourceGroup -Name $rgname -Location $location
Start-Sleep -Seconds 5
#Deploy Environment
Write-Output -InputObject "Initiating Resources...$(get-date)"
New-AzResourceGroupDeployment -Name 'dbtVmDeploy' -ResourceGroupName $rgname -TemplateFile .\main.bicep -Location $location -vmName $vmName -adminUsername $adminUsername -adminPassword $adminPassword -vmSize $vmSize