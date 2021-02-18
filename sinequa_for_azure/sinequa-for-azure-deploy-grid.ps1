# README
# allow execution of scripts by : PS> Set-ExecutionPolicy RemoteSigned
# Install-Module -Name Az -AllowClobber -Force
# Install-Module -Name Azure -AllowClobber -Force
# Connect-AzAccount


#---------------------------------------------------------- 
# ARGUMENTS
#---------------------------------------------------------- 

param (
   
    [Parameter(HelpMessage = "Azure Subscription Id")]
    [string]    $subscriptionId = "8a9fc7e2-ac08-4009-8498-2026cb37bb25", #subscription id of "sub-snqa-sandbox"

    [Parameter(HelpMessage = "ARM Template")]
    [string]    $templateFile = "./mainTemplate.json",

    [Parameter(HelpMessage = "ARM Template Parameters")]
    [string]    $templateParameterFile = "./mainTemplate.parameters.json",

    [Parameter(HelpMessage = "Resource Group Name")]
    [string]    $resourceGroupName = "fred_test"
)



# ERROR REPORTING ALL 
Set-StrictMode -Version latest;
$ErrorActionPreference = "Stop"
$StartTime = Get-Date


#Connect-AzAccount
Set-AzContext $subscriptionId 

$publisher = "sinequa"
$product = "sinequa_virtual_machine"
$name = "nightly"

# Accepts Terms of the Sinequa Plan
$terms = Get-AzMarketplaceTerms -Publisher $publisher -Product $product -Name $name
$null = Set-AzMarketplaceTerms -Publisher $publisher -Product $product -Name $name -Accept -Terms $terms

# Deploy
$null = New-AzResourceGroupDeployment `
  -Name "ManualDeploymentViaPS" `
  -ResourceGroupName $resourceGroupName `
  -TemplateFile $templateFile `
  -TemplateParameterFile $templateParameterFile `
  -Verbose

$EndTime = Get-Date
Write-Host "Script execution time: $($EndTime - $StartTime)"
