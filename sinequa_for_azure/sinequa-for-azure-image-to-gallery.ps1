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
    [string]    $subscriptionId = "$env:AZURE_PRODUCT_SUBSCRIPTION",

    [Parameter(HelpMessage = "Azure User Login")]
    [string]    $user = "$env:AZURE_BUILD_USER",

    [Parameter(HelpMessage = "Azure User Password")]
    [SecureString]    $password = ("$env:AZURE_BUILD_PWD" |  where-Object {$_} | ConvertTo-SecureString -AsPlainText -Force),

    [Parameter(HelpMessage = "Azure Location")]
    [string]    $location = "francecentral",

    [Parameter(HelpMessage = "Image Resource Group Name")]
    [string]    $imageResourceGroupName = "Product",    

    [Parameter(HelpMessage = "Shared Image Gallery Name")]
    [string]    $galleryName = "SinequaForAzure",    

    [Parameter(HelpMessage = "Image Definition Name")]
    [string]    $imageDefinitionName = "sinequa-11-nightly",    

    [Parameter(HelpMessage = "Sinequa Image Name")]
    [string]    $imageName = "sinequa-nightly-11.5.0.100",    

    [Parameter(HelpMessage = "Sinequa Build Version")]
    [string]    $version = "11.5.0.100",

    [Parameter(HelpMessage = "Delete old images")]
    [bool]    $deleteOlds = $false    
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
$maxImagesToKeep = 5

# Azure Login
SqAzurePSLogin -tenantId $tenantId -subscriptionId $subscriptionId -user $user -password $password

# Get Resource Group
$rg = Get-AzResourceGroup -Name $imageResourceGroupName -Location $location 

# Get Image
WriteLog "Get '$imageName' Image"
$image = Get-AzImage -ResourceGroupName $imageResourceGroupName -ImageName $imageName

# Create Image Definition
WriteLog "Create '$galleryName/$imageDefinitionName' Image Definition "
$imageDef = SqAzurePSCreateImageVersion -resourceGroup $rg -galleryName $galleryName -imageDefinitionName $imageDefinitionName -version $version -image $image
$imageDef

#Delete old images
if ($deleteOlds) {
    $imageNamePrefix = $imageName.Replace($version,'')
    WriteLog "Delete old images for $imageNamePrefix"
    Get-AzImage -ResourceGroupName $imageResourceGroupName | Where-Object {$_.Name -like "$imageNamePrefix*"} | Sort-Object -Property @{Expression={[int][RegEx]::Match($_.Name, "([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$").Groups[1].value}},@{Expression={[int][RegEx]::Match($_.Name, "([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$").Groups[2].value}},@{Expression={[int][RegEx]::Match($_.Name, "([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$").Groups[3].value}},@{Expression={[int][RegEx]::Match($_.Name, "([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$").Groups[4].value}} | Select-Object  -SkipLast $maxImagesToKeep | Remove-AzImage -Force  -ErrorAction SilentlyContinue

    WriteLog "Delete old images definition for $imageDefinitionName"
    Get-AzGalleryImageVersion  -GalleryImageDefinitionName $imageDefinitionName  -ResourceGroupName $imageResourceGroupName -GalleryName $galleryName | Sort-Object -Property @{Expression={[int][RegEx]::Match($_.Name, "([0-9]+)\.([0-9]+)\.([0-9]+)$").Groups[1].value}},@{Expression={[int][RegEx]::Match($_.Name, "([0-9]+)\.([0-9]+)\.([0-9]+)$").Groups[2].value}},@{Expression={[int][RegEx]::Match($_.Name, "([0-9]+)\.([0-9]+)\.([0-9]+)$").Groups[3].value}} |  Select-Object -SkipLast $maxImagesToKeep | Remove-AzGalleryImageVersion -Force -ErrorAction SilentlyContinue
}

$EndTime = Get-Date
WriteLog "Script execution time: $($EndTime - $StartTime)"