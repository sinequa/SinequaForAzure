# README
# allow execution of scripts by : PS> Set-ExecutionPolicy RemoteSigned
# Install-Module -Name Az -AllowClobber -Force
# Install-Module -Name Azure -AllowClobber -Force
# Connect-AzAccount


#---------------------------------------------------------- 
# ARGUMENTS
#---------------------------------------------------------- 

param (
    [Parameter(HelpMessage = "Azure Tenant Id")]
    [string]    $tenantId = "$env:AZURE_PRODUCT_TENANT",
    
    [Parameter(HelpMessage = "Azure Subscription Id")]
    [string]    $subscriptionId = "$env:AZURE_PRODUCT_SUBSCRIPTION",

    [Parameter(HelpMessage = "Azure User Login")]
    [string]    $user = "$env:AZURE_BUILD_USER",

    [Parameter(HelpMessage = "Azure User Password")]
    [SecureString]    $password = ("$env:AZURE_BUILD_PWD" |  where-Object {$_} | ConvertTo-SecureString -AsPlainText -Force),

    [Parameter(HelpMessage = "Azure Location")]
    [string]    $location = "francecentral",

    [Parameter(HelpMessage = "Image Resource Group Name")]
    [string]    $imageResourceGroupName = "rg-sinequa",    

    [Parameter(HelpMessage = "Image Name")]
    [string]    $imageName = "sinequa-base-image",    

    [Parameter(HelpMessage = "Temp Resource Group for building the image")]
    [string]    $tempResourceGroupName = "temp-sinequa-base-image",

    [Parameter(HelpMessage = "OS User of the VM")]
    [string]    $osUsername = "sinequa",

    [Parameter(HelpMessage = "OS Password of the VM")]
    [SecureString]    $osPassword = ("Password1234" |  where-Object {$_} | ConvertTo-SecureString -AsPlainText -Force),

    [Parameter(HelpMessage = "Image SKU of WindowsServer")]
    [string]    $imageSku = "2022-datacenter-smalldisk",

    [Parameter(HelpMessage = "VM Size")]

    [string]    $vmSize = "Standard_D4s_v3",
    
    [Parameter(HelpMessage = "Tags (""-Tags @{'tagname' = 'tagvalue'}""")]
    [hastable]    $tags
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
$vmName = "vm-" + $imageName
$nodeName = "sq-base"
$bgFile = ".\config.bgi"

# for debugging
$cleanExistingResourceGroup = $true 
$forceProgramsInstall = $true

# Azure Login
SqAzurePSLogin -tenantId $tenantId -subscriptionId $subscriptionId -user $user -password $password


# Temp Resource Group
$rg = Get-AzResourceGroup -Name $tempResourceGroupName -Location $location  -ErrorAction SilentlyContinue
if ($rg -and $cleanExistingResourceGroup) {
    #Delete the temp resource group if exists
    $null = Remove-AzResourceGroup -Name $tempResourceGroupName -Force
}
$rg = Get-AzResourceGroup -Name $tempResourceGroupName -Location $location -ErrorAction SilentlyContinue
if (!$rg) {
    #Create the temp resource group
    WriteLog "Create the temp resource group: $tempResourceGroupName"
    $rg = New-AzResourceGroup -Name $tempResourceGroupName -Tag $tags -Location $location
}


# Get Image if already exists & Create a Virtual Machine
$image = Get-AzImage -ResourceGroupName $imageResourceGroupName -ImageName $imageName -ErrorAction SilentlyContinue
if ($image) {
    # delete previous image
    WriteLog "Delete existing image"
    Remove-AzImage -ResourceGroupName $imageResourceGroupName -ImageName $imageName -Force;
    $image = $null
}
$vm = Get-AzVM -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue | Where-Object {$_.Tags['sinequa'] -eq $imageName} -ErrorAction SilentlyContinue
if (!$vm) {
    WriteLog "Create Temp VM"
    $vm = SqAzurePSCreateTempVM -resourceGroup $rg -image $image -vmName $vmName -nodeName $nodeName -osUsername $osUsername -osPassword $osPassword -sku $imageSku -vmSize $vmSize -tags tags
}
$vm = Get-AzVM -ResourceGroupName $rg.ResourceGroupName -vmName $vmName

#If image doesn't exists, then it's the first image => run init script
if (!$image -or $forceProgramsInstall) {
    WriteLog "Install Programs"
    # upload the bginfo file into a transient storage account
    $bgFileUrl = (SqAzurePSLocalFileToRGStorageAccount -resourceGroup $rg -imageName $imageName -localFile $bgFile)[1]
    # run script for install prerequisites and optional programs
    $script = ".\sinequa-az-cse-install-programs.ps1"
    $parameters = @{bgFileUrl =  """$bgFileUrl"""}
    SqAzurePSRunScript -resourceGroupName $rg.ResourceGroupName -vmName $vmName -scriptName $script -parameters $parameters
}

#Apply Windows Updates
$script = ".\sinequa-az-cse-windows-update.ps1"
SqAzurePSApplyWindowsUpdates -resourceGroupName $rg.ResourceGroupName -vmName $vmName -scriptName $script

#Generalyze the VM
WriteLog "Generalize the VM"
$script = ".\sinequa-az-cse-sysprep.ps1"
SqAzurePSRunScript -resourceGroupName $rg.ResourceGroupName -vmName $vmName -scriptName $script

# Create the Image
$vm = Get-AzVM -Name $vmName -ResourceGroupName $rg.ResourceGroupName
$null = SqAzurePSCreateImage -resourceGroupName $imageResourceGroupName -imageName $imageName -vm $vm

#Delete the temp resource group
WriteLog "Delete Resource Group: $rg.ResourceGroupName"
$null = Remove-AzResourceGroup -Name $rg.ResourceGroupName -Force

$EndTime = Get-Date
WriteLog "Script execution time: $($EndTime - $StartTime)"