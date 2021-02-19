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

    [Parameter(HelpMessage = "Sinequa Base Image")]
    [string]    $baseImageName = "sinequa-base-image",    

    [Parameter(HelpMessage = "Sinequa Image Name")]
    [string]    $imageName = "sinequa-nightly-11.5.1.51",    

    [Parameter(HelpMessage = "Sinequa Build Version")]
    [string]    $version = "11.5.1.51",    

    [Parameter(HelpMessage = "Local Sinequa Zip file")]
    [string]    $localFile,    

    [Parameter(HelpMessage = "URI of the Sinequa Zip file")]
    [string]    $fileUrl = "https://99b96456b04149199ed39cac.blob.core.windows.net/build/sinequa.11.zip?sv=2019-07-07&sr=c&sig=2xOhdvH8W1t0SSzReormQ13ULopY2ZOQijRqVVE0URc%3D&st=2021-02-14T15%3A55%3A20Z&se=2021-02-16T15%3A55%3A20Z&sp=rl",    

    [Parameter(HelpMessage = "Temp Resource Group for building the image")]
    [string]    $tempResourceGroupName = "temp-sinequa-image-11.5.1.51",

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
$vmName = "vm-sq-" + $version.Replace(".","-")
$vmName = $vmName.Substring(0,14)
$nodeName = "sq-version"
$startupFile = ".\sinequa-az-startup.ps1"

# Azure Login
SqAzurePSLogin -tenantId $tenantId -subscriptionId $subscriptionId -user $user -password $password

# for debugging
$cleanExistingResourceGroup = $false 

# Temp Resource Group
WriteLog "Temp Resource Group: $tempResourceGroupName"
$rg = Get-AzResourceGroup -Name $tempResourceGroupName -Location $location  -ErrorAction SilentlyContinue
if ($rg -and $cleanExistingResourceGroup) {
    #Delete the temp resource group if exists
    Remove-AzResourceGroup -Name $tempResourceGroupName -Force
}
$rg = Get-AzResourceGroup -Name $tempResourceGroupName -Location $location  -ErrorAction SilentlyContinue
if (!$rg) {
    #Create the temp resource group
    WriteLog "Create the temp resource group: $tempResourceGroupName"
    $rg = New-AzResourceGroup -Name $tempResourceGroupName -Location $location
}

# Get Image if already exists & Create a Virtual Machine
$baseImage = Get-AzImage -ResourceGroupName $imageResourceGroupName -ImageName $baseImageName
$vm = Get-AzVM -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue | Where-Object {$_.Tags['sinequa'] -eq $imageName} -ErrorAction SilentlyContinue
if (!$vm) {
    $vm = SqAzurePSCreateTempVM -resourceGroup $rg -image $baseImage -vmName $vmName -nodeName $nodeName -osUsername $osUsername -osPassword $osPassword
}

#If Local File, copy it into the storage account
if (($localFile.Length -gt 0) -and (Test-Path $localFile)) {
    $res = SqAzurePSLocalFileToRGStorageAccount -resourceGroup $rg -localFile $localFile -imageName $imageName
    $fileUrl = ($res)[1]
}
if ($fileUrl.Length -eq 0) {
    WriteError("fileUrl is empty")
    Exit 1
}

#Install Sinequa
$startupFileUrl = (SqAzurePSLocalFileToRGStorageAccount -resourceGroup $rg -imageName $imageName -localFile $startupFile)[1]

$script = ".\sinequa-az-cse-install-build.ps1"
$parameters = @{fileUrl = """$fileUrl"""; startupFileUrl = """$startupFileUrl"""}
SqAzurePSRunScript -resourceGroupName $rg.ResourceGroupName -vmName $vmName -scriptName $script -parameters $parameters


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