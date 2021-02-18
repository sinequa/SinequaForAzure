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
    [string]    $tenantId = "465ec3fd-500e-4e38-a426-5ca3086440bd",
    
    [Parameter(HelpMessage = "Azure Subscription Id")]
    [string]    $subscriptionId = "05cdfb61-fbbb-43a9-b505-cd1838fff60e",

    [Parameter(HelpMessage = "Azure User Login")]
    [string]    $user = "$env:AZURE_BUILD_USER",

    [Parameter(HelpMessage = "Azure User Password")]
    [SecureString]    $password = ("$env:AZURE_BUILD_PWD" |  where-Object {$_} | ConvertTo-SecureString -AsPlainText -Force),

    [Parameter(HelpMessage = "Azure Location")]
    [string]    $location = "westeurope",

    [Parameter(HelpMessage = "Image Resource Group Name")]
    [string]    $imageResourceGroupName = "Product",    

    [Parameter(HelpMessage = "Image Name")]
    [string]    $imageName = "sinequa-base-image",    

    [Parameter(HelpMessage = "Temp Resource Group for building the image")]
    [string]    $tempResourceGroupName = "temp-sinequa-base-image",

    [Parameter(HelpMessage = "OS User of the VM")]
    [string]    $osUsername = "sinequa",

    [Parameter(HelpMessage = "OS Password of the VM")]
    [SecureString]    $osPassword = ("Password2020" |  where-Object {$_} | ConvertTo-SecureString -AsPlainText -Force)
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
$bgFile = ".\config.bgi"

# for debugging
$cleanExistingResourceGroup = $false 
$forceProgramsInstall = $true

# Azure Login
SqAzurePSLogin -tenantId $tenantId -subscriptionId $subscriptionId -user $user -password $password


# Temp Resource Group
$rg = Get-AzResourceGroup -Name $tempResourceGroupName -Location $location  -ErrorAction SilentlyContinue
if ($rg -and $cleanExistingResourceGroup) {
    #Delete the temp resource group if exists
    $null = Remove-AzResourceGroup -Name $tempResourceGroupName -Force
}
$rg = Get-AzResourceGroup -Name $tempResourceGroupName -Location $location  -ErrorAction SilentlyContinue
if (!$rg) {
    #Create the temp resource group
    WriteLog "Create the temp resource group: $tempResourceGroupName"
    $rg = New-AzResourceGroup -Name $tempResourceGroupName -Location $location
}


# Get Image if already exists & Create a Virtual Machine
$image = Get-AzImage -ResourceGroupName $imageResourceGroupName -ImageName $imageName -ErrorAction SilentlyContinue
$vm = Get-AzVM -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue | Where-Object {$_.Tags['sinequa'] -eq $imageName} -ErrorAction SilentlyContinue
if (!$vm) {
    $vm = SqAzurePSCreateTempVM -resourceGroup $rg -image $image -vmName $vmName -osUsername $osUsername -osPassword $osPassword
}
$vm = Get-AzVM -ResourceGroupName $rg.ResourceGroupName -vmName $vmName

#If image doesn't exists, then it's the first image => run init script
if (!$image -or $forceProgramsInstall) {
    $bgFileUrl = (SqAzurePSLocalFileToRGStorageAccount -resourceGroup $rg -imageName $imageName -localFile $bgFile)[1]
    $script = ".\sinequa-az-cse-install-programs.ps1"
    $parameters = @{bgFileUrl = $bgFileUrl}
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