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
    [string]    $subscriptionId = "8a9fc7e2-ac08-4009-8498-2026cb37bb25", #subscription id of "sub-snqa-sandbox"

    [Parameter(HelpMessage = "Azure User Login")]
    [string]    $user = "$env:AZURE_BUILD_USER",

    [Parameter(HelpMessage = "Azure User Password")]
    [SecureString]    $password = ("$env:AZURE_BUILD_PWD" |  where-Object {$_} | ConvertTo-SecureString -AsPlainText -Force),

    [Parameter(HelpMessage = "Azure Location")]
    [string]    $location = "francecentral",

    [Parameter(HelpMessage = "Resource Group Name of the Sinequa GRID")]
    [string]    $resourceGroupName,    
    
    [Parameter(HelpMessage = "Sinequa Image Reference")]
    [string]    $imageReferenceId = "/subscriptions/e88f44fe-533b-4811-a972-5f6a692b0730/resourceGroups/Product/providers/Microsoft.Compute/galleries/SinequaForAzure/images/sinequa-11-nightly",    

    [Parameter(HelpMessage = "Node Name")]
    [string]    $nodeName = "",

    [Parameter(HelpMessage = "Engine Name")]
    [string]    $engineName = "",

    [Parameter(HelpMessage = "Indexer Name")]
    [string]    $indexerName = "",

    [Parameter(HelpMessage = "WebApp Name")]
    [string]    $webAppName = ""
)



# ERROR REPORTING ALL 
Set-StrictMode -Version latest;
$ErrorActionPreference = "Stop"
$StartTime = Get-Date

# Remove WARNING: breaking changes...
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

# Include Sinequa Functions
. .\sinequa_az_ps_functions.ps1

# Variables

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

# Get Resource Group
WriteLog "Check Resource Group: $resourceGroupName"
$rg = Get-AzResourceGroup -Name $resourceGroupName -Location $location 

# Get existing VMs
WriteLog "Get existing VMs from the '$($rg.ResourceGroupName)' Resource Group"
[array]$vms = Get-AzVM -ResourceGroupName $rg.ResourceGroupName | Where-Object {$_.Tags['Sinequa_Grid']}
if (!$vms) {
    WriteError "No Sinequa Grid or VM in the $($rg.ResourceGroupName) resource group"
    Exit 1
}
$vmCount = $vms.Length


# Get Tags
$tags = SqAzurePSGetTagsFromGrid -vms $vms
$sinequaGrid = $tags.Sinequa_Grid
$sinequaKeyVault = $tags.Sinequa_KeyVault
if ($nodeName.Length -eq 0) {$nodeName = $vmCount +1}
$hostName = "node-$nodeName"
$vmName = "vm-$sinequaGrid-$($nodeName)" 

$tags.Add("Sinequa_NodeName", $hostName)
$tags.Add("Sinequa_Role", "Regular Node")
$tags.Add("Sinequa_AutoDisk", "auto")
$tags.Add("Sinequa_Path", "F:\sinequa")
if ($engineName.length -gt 0) { $tags.Add("Sinequa_Engine", $engineName) }
if ($indexerName.length -gt 0) { $tags.Add("Sinequa_Indexer", $engineName) }
if ($webAppName.length -gt 0) { $tags.Add("Sinequa_WebApp", $webAppName) }

WriteLog " ==> Add '$vmName' as a $($tags.Sinequa_Role) in the Sinequa Grid"

# Get existing Storage Account
WriteLog "Get existing Storage Account from the '$sinequaGrid' Sinequa Grid"
$sa = Get-AzStorageAccount -ResourceGroupName $rg.ResourceGroupName | Where-Object {$_.Tags -and ($_.Tags['Sinequa_Grid'] -eq $sinequaGrid)}

# Get Nic of the first existing VM for retreiving netwtork settings
WriteLog "Get an existing NIC configuration from resource group"
[array] $vmNics = Get-AzNetworkInterface -ResourceGroupName $rg.ResourceGroupName | Where-Object {$_.Tag -and ($_.Tag['Sinequa_Grid'] -eq $sinequaGrid)} 
$vmNic = $vmNics[0]
$ngs = $vmNic.NetworkSecurityGroup
$subnet = $vmNic.IpConfigurations[0].Subnet

# Get Keyvaul for os user/password
$userId = (Get-AzContext).Account.Id
$roleDefinitionName = "Key Vault Secrets User"
WriteLog "Read secrets in $sinequaKeyVault"
WriteLog "Requires the Key '$roleDefinitionName' role on $($rg.ResourceGroupName) for $userId"
$role = Get-AzRoleAssignment -ResourceGroupName $rg.ResourceGroupName -SignInName  $userId -RoleDefinitionName $roleDefinitionName
if (-Not $role) {
    WriteLog "Add transient '$roleDefinitionName' role on $($rg.ResourceGroupName) for $userId"
    $null = New-AzRoleAssignment -ResourceGroupName $rg.ResourceGroupName -SignInName  $userId -RoleDefinitionName $roleDefinitionName
    Start-Sleep -s 15
}
$osUsername = SqAzurePSGetSecret -keyVaultName $sinequaKeyVault -secretName "os-username"
$osPassword = SqAzurePSGetSecret -keyVaultName $sinequaKeyVault -secretName "os-password" | ConvertTo-SecureString -Force -AsPlainText
if (-Not $role) {
    WriteLog "Remove transient '$roleDefinitionName' role on $($rg.ResourceGroupName) for $userId"
    $null = Remove-AzRoleAssignment -ResourceGroupName $rg.ResourceGroupName -SignInName  $userId -RoleDefinitionName $roleDefinitionName    
}

# Get Image
$image = SqAzGetImageByRefId -referenceId $imageReferenceId -context $imageContext
if (!$image) {
    Exit 1
}
 
 ## Create the virtual machine
SqAzurePSCreateVMforNode `
 -resourceGroup $rg `
 -storageAccount $sa `
 -createPip $true `
 -prefix $sinequaGrid `
 -image $image `
 -hostname $hostname `
 -nodeName $nodeName `
 -vmName $vmName `
 -nsg $ngs `
 -subnet $subnet `
 -osUsername $osUsername `
 -osPassword $osPassword `
 -tags $tags `
 -vmSize "Standard_D8s_v3" `
 -dataDiskSizeInGB 1024

$vm = Get-AzVm -Name $vmName -ResourceGroupName $rg.ResourceGroupName

# Add IAM roles 
WriteLog "Add 'Reader' role on '$rg.ResourceGroupName'"
$null = New-AzRoleAssignment -ObjectId $vm.Identity.PrincipalID -RoleDefinitionName "Reader" -ResourceGroupName $rg.ResourceGroupName
WriteLog "Add 'Contributor' role on '$($sa.StorageAccountName)'"
$null = New-AzRoleAssignment -ObjectId $vm.Identity.PrincipalID -RoleDefinitionName "Contributor" -ResourceGroupName $rg.ResourceGroupName
WriteLog "Add 'Key Vault Secrets Officer' role on '$sinequaKeyVault'"
$null = New-AzRoleAssignment -ObjectId $vm.Identity.PrincipalID -RoleDefinitionName "Key Vault Secrets Officer" -ResourceGroupName $rg.ResourceGroupName
	
$EndTime = Get-Date
WriteLog "Script execution time: $($EndTime - $StartTime)"