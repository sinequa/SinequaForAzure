# README
# allow execution of scripts by : PS> Set-ExecutionPolicy RemoteSigned
# Install-Module -Name Az -AllowClobber -Force
# Connect-AzAccount


#---------------------------------------------------------- 
# ARGUMENTS
#---------------------------------------------------------- 

param (

    [Parameter(HelpMessage = "Azure Tenant Id")]
    [string]    $tenantId = "465ec3fd-500e-4e38-a426-5ca3086440bd",
    
    [Parameter(HelpMessage = "Azure Subscription Id")]
    [string]    $subscriptionId = "8a9fc7e2-ac08-4009-8498-2026cb37bb25", #"05cdfb61-fbbb-43a9-b505-cd1838fff60e",

    [Parameter(HelpMessage = "Azure User Login")]
    [string]    $user = "$env:AZURE_BUILD_USER",

    [Parameter(HelpMessage = "Azure User Password")]
    [SecureString]    $password = ("$env:AZURE_BUILD_PWD" |  where-Object {$_} | ConvertTo-SecureString -AsPlainText -Force),

    [Parameter(HelpMessage = "Azure Location")]
    [string]    $location = "francecentral",

    [Parameter(HelpMessage = "Resource Group Name of the Sinequa GRID")]
    [string]    $resourceGroupName,    
    
    [Parameter(HelpMessage = "VmSS Name to Upgrade")]
    [string]    $vmssName = "vmss-sq-connector",    

    [Parameter(HelpMessage = "Sinequa Image Reference")]
    [string]    $imageReferenceId = "/subscriptions/e88f44fe-533b-4811-a972-5f6a692b0730/resourceGroups/Product/providers/Microsoft.Compute/galleries/SinequaForAzure/images/sinequa-11-nightly"    

)

# ERROR REPORTING ALL 
Set-StrictMode -Version latest;
$ErrorActionPreference = "Stop"
$StartTime = Get-Date

# Include Sinequa Functions
. .\sinequa_az_ps_functions.ps1

# Detect if Gallery (if used) is in another subscription
$imageContext = $null
$gallerySubscriptionId = $imageReferenceId.Split("/")[2]
if ($gallerySubscriptionId -eq $subscriptionId) { $gallerySubscriptionId = $null }

# Azure Login for Image Gallery (in case of another subscription)
$imageContext = $null
if ($gallerySubscriptionId) {
    $imageContext = SqAzurePSLogin -tenantId $tenantId -subscriptionId $gallerySubscriptionId -user $user -password $password
}
# Azure Login
SqAzurePSLogin -tenantId $tenantId -subscriptionId $subscriptionId -user $user -password $password

# Get Image
$image = SqAzGetImageByRefId -referenceId $imageReferenceId -context $imageContext
if (!$image) {
    Exit 1
}

# Get Resource Group
WriteLog "Check Resource Group: $resourceGroupName"
$rg = Get-AzResourceGroup -Name $resourceGroupName -Location $location 

# Get VMSS
$vmss = Get-AzVmss -Name $vmssName -ResourceGroupName $resourceGroupName   
$sinequaKeyVault = $vmss.Tags.Sinequa_KeyVault


# Get KeyVault for os user/password
# Get Keyvaul for os user/password
$userId = (Get-AzContext).Account.Id
$roleDefinitionName = "Key Vault Secrets Officer"
WriteLog "Read secrets in $sinequaKeyVault"
WriteLog "Requires the Key '$roleDefinitionName' role on $($resourceGroupName) for $userId"
$role = Get-AzRoleAssignment -ResourceGroupName $resourceGroupName -SignInName  $userId -RoleDefinitionName $roleDefinitionName
if (-Not $role) {
    WriteLog "Add transient '$roleDefinitionName' role on $($resourceGroupName) for $userId"
    $null = New-AzRoleAssignment -ResourceGroupName $resourceGroupName -SignInName  $userId -RoleDefinitionName $roleDefinitionName
    Start-Sleep -s 15
}
$null = Get-AzRoleAssignment -ResourceGroupName $resourceGroupName -SignInName  $userId -RoleDefinitionName $roleDefinitionName
$osUsername = SqAzurePSGetSecret -keyVaultName $sinequaKeyVault -secretName "os-username"
$osPassword = SqAzurePSGetSecret -keyVaultName $sinequaKeyVault -secretName "os-password" | ConvertTo-SecureString -Force -AsPlainText
if (-Not $role) {
    WriteLog "Remove transient '$roleDefinitionName' role on $($resourceGroupName) for $userId"
    $null = Remove-AzRoleAssignment -ResourceGroupName $resourceGroupName -SignInName  $userId -RoleDefinitionName $roleDefinitionName    
}

WriteLog "Remove VM ScaleSet: $vmssName"
$null = Remove-AzVmss -ResourceGroupName $resourceGroupName -VMScaleSetName $vmssName -Force

## Create the virtual machine
 SqAzurePSCreateVMSSforNode `
 -resourceGroup $rg `
 -image $image `
 -vmssName $vmssName `
 -subnet $vmss.VirtualMachineProfile.NetworkProfile.NetworkInterfaceConfigurations[0].IpConfigurations[0].Subnet `
 -osUsername $osUsername `
 -osPassword $osPassword `
 -tags $vmss.Tags 


$EndTime = Get-Date
WriteLog "[$($vmssName)] Script ($($MyInvocation.MyCommand.Name)) Execution time: $($EndTime - $StartTime)"