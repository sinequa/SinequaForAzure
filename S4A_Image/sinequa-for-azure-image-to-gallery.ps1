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

    [Parameter(HelpMessage = "Shared Image Gallery Name")]
    [string]    $galleryName = "SinequaForAzure",    

    [Parameter(HelpMessage = "Image Definition Name")]
    [string]    $imageDefinitionName = "sinequa-11-nightly",    

    [Parameter(HelpMessage = "Image Definition Target Regions; eg. ""-targetRegions @('westeurope','francecentral')""")]
    [array]    $targetRegions,    

    [Parameter(HelpMessage = "Sinequa Image Name to share")]
    [string]    $imageName,    

    [Parameter(HelpMessage = "Sinequa Build Version")]
    [string]    $version,

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

if (-not (isSinequaVersion -version $version)) {
    WriteError("'$version' is not a valid version (x.y.z or x.y.z.r)")
    Exit 1   
}

# Variables
# Number of image to keep
$maxImagesToKeep = 5

# Azure Login
SqAzurePSLogin -tenantId $tenantId -subscriptionId $subscriptionId -user $user -password $password -environmentName $environmentName

# Get Resource Group
$rg = Get-AzResourceGroup -Name $imageResourceGroupName -Location $location 

# Get Image
WriteLog "Get '$imageName' Image"
$image = Get-AzImage -ResourceGroupName $imageResourceGroupName -ImageName $imageName
if (!$image) {
    WriteError("'$imageName' not found")
    Exit 1   
}

# Create Image Definition
WriteLog "Create '$galleryName/$imageDefinitionName' Image Definition "
$imageDef = SqAzurePSCreateImageVersion -resourceGroup $rg -galleryName $galleryName -imageDefinitionName $imageDefinitionName -version $version -image $image -targetRegions $targetRegions
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