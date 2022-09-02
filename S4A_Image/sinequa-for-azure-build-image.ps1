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

    [Parameter(HelpMessage = "Azure Environment Name")]
    [string]    $environmentName  = "AzureCloud",

    [Parameter(HelpMessage = "Azure Location")]
    [string]    $location = "francecentral",

    [Parameter(HelpMessage = "Image Resource Group Name")]
    [string]    $imageResourceGroupName = "rg-sinequa",    

    [Parameter(HelpMessage = "Sinequa Base Image")]
    [string]    $baseImageName = "sinequa-base-image",    

    [Parameter(HelpMessage = "Sinequa Image Name")]
    [string]    $imageName,    

    [Parameter(HelpMessage = "Sinequa Build Version")]
    [string]    $version,    

    [Parameter(HelpMessage = "Local Sinequa Zip file")]
    [string]    $localFile = "",    

    [Parameter(HelpMessage = "URI of the Sinequa Zip file")]
    [string]    $fileUrl = "",    

    [Parameter(HelpMessage = "Temp Resource Group for building the image")]
    [string]    $tempResourceGroupName = "temp-sinequa-image",

    [Parameter(HelpMessage = "OS User of the VM")]
    [string]    $osUsername = "sinequa",

    [Parameter(HelpMessage = "OS Password of the VM")]
    [SecureString]    $osPassword = ("Password1234" |  where-Object {$_} | ConvertTo-SecureString -AsPlainText -Force),
    
    [Parameter(HelpMessage = "Tags (""-Tags @{'tagname' = 'tagvalue'}""")]
    [hashtable]    $tags
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
if ($vmName.Length -gt 14) {
    $vmName = $vmName.Substring(0,14)
}
$nodeName = "sq-version"


# Azure Login
SqAzurePSLogin -tenantId $tenantId -subscriptionId $subscriptionId -user $user -password $password -environmentName $environmentName

# for debugging
$cleanExistingResourceGroup = $false 

# Test Inputs
if (-not (isSinequaVersion -version $version)) {
    WriteError("'$version' is not a valid version (x.y.z or x.y.z.r)")
    Exit 1   
}
if (($localFile.Length -gt 0) -and (-not(Test-Path $localFile))) {
    WriteError("'$localFile' localFile doesn't exist.")
    Exit 1   
}

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
    $rg = New-AzResourceGroup -Name $tempResourceGroupName -Tag $tags -Location $location
}

# Get Image if already exists & Create a Virtual Machine
$baseImage = Get-AzImage -ResourceGroupName $imageResourceGroupName -ImageName $baseImageName
$vm = Get-AzVM -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue | Where-Object {$_.Tags['sinequa'] -eq $imageName} -ErrorAction SilentlyContinue
if (!$vm) {
    $vm = SqAzurePSCreateTempVM -resourceGroup $rg -image $baseImage -vmName $vmName -nodeName $nodeName -osUsername $osUsername -osPassword $osPassword -tags $tags
}

#Apply Windows Updates
$script = ".\sinequa-az-cse-windows-update.ps1"
SqAzurePSApplyWindowsUpdates -resourceGroupName $rg.ResourceGroupName -vmName $vmName -scriptName $script


#If Local File, copy it into the storage account
if (($localFile.Length -gt 0) -and (Test-Path $localFile)) {
    $res = SqAzurePSLocalFileToRGStorageAccount -resourceGroup $rg -localFile $localFile -imageName $imageName
    $fileUrl = ($res)[1]
}
if ($fileUrl.Length -eq 0) {
    WriteError("fileUrl or localFile is empty")
    Exit 1
}

#Install Sinequa
$script = ".\sinequa-az-cse-install-build.ps1"
$parameters = @{fileUrl = """$fileUrl"""}
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
