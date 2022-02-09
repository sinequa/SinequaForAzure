
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

    [Parameter(HelpMessage = "User Identity")]
    [string]    $imgBuilderId,    

    [Parameter(HelpMessage = "Image SKU of WindowsServer")]
    [string]    $imageSku = "2022-Datacenter-smalldisk"
    
)
# ERROR REPORTING ALL 
Set-StrictMode -Version latest;
$ErrorActionPreference = "Stop"
$StartTime = Get-Date

#https://docs.microsoft.com/en-us/azure/virtual-machines/windows/image-builder

az account set --subscription $subscriptionId
$template = "sinequa-base-image.json"
$imageId = "/subscriptions/$subscriptionId/resourceGroups/$imageResourceGroupName/providers/Microsoft.Compute/images/$imageName"
Copy-Item sinequa-base-image-template.json -Destination "./$template" -Force
(Get-Content $template) | ForEach-Object{$_ -replace "<imgBuilderId>", $imgBuilderId} | Set-Content $template
(Get-Content $template) | ForEach-Object{$_ -replace "<imageSku>", $imageSku} | Set-Content $template
(Get-Content $template) | ForEach-Object{$_ -replace "<location>", $location} | Set-Content $template
(Get-Content $template) | ForEach-Object{$_ -replace "<imageID>", "$imageId"} | Set-Content $template

az resource create `
    --resource-group $imageResourceGroupName `
    --properties @$template `
    --is-full-object `
    --location $location `
    --resource-type Microsoft.VirtualMachineImages/imageTemplates `
    --name "sinequa-base-image-template"


    
$EndTime = Get-Date
Write-Host "Script execution time: $($EndTime - $StartTime)"