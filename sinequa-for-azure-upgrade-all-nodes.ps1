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
    [string]    $location = "westeurope",

    [Parameter(HelpMessage = "Resource Group Name of the Sinequa GRID")]
    [string]    $resourceGroupName = "fred_test2",    
    
    [Parameter(HelpMessage = "Sinequa Image Reference")]
    [string]    $imageReferenceId = "/subscriptions/05cdfb61-fbbb-43a9-b505-cd1838fff60e/resourceGroups/Product/providers/Microsoft.Compute/galleries/SinequaForAzure/images/sinequa-11-nightly/5.1.54"
)



# ERROR REPORTING ALL 
Set-StrictMode -Version latest;
$ErrorActionPreference = "Stop"
$StartTime = Get-Date

# Remove WARNING: breaking changes...
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

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

# Get VMs to Update
WriteLog "Get existing VMs from the '$($rg.ResourceGroupName)' Resource Group with Sinequa_Image!=$($image.Name)"
[array]$vms = Get-AzVM -ResourceGroupName $rg.ResourceGroupName | Where-Object {$_.Tags['Sinequa_Grid'] -and ($_.Tags['Sinequa_Image'] -ne $image.Name)}

WriteLog "Get existing VMsss from the '$($rg.ResourceGroupName)' Resource Group with Sinequa_Image!=$($image.Name)"
[array]$vmsss = Get-AzVmss -ResourceGroupName $rg.ResourceGroupName | Where-Object {$_.Tags['Sinequa_Grid'] -and ($_.Tags['Sinequa_Image'] -ne $image.Name)}

# Get Tags
$tags = SqAzurePSGetTagsFromGrid -vms $vms -vmsss $vmsss
if (!$tags) {
    Exit 0
}

# Used for multi-threading
$scriptBlocSqAzurePSUpdateVM = {
    param ($tenantId, $subscriptionId, $user, [secureString] $password, $resourceGroupName, $location, $vmName, $imageReferenceId)
      
        # Update a VM
        . .\sinequa-for-azure-upgrade-vm-node.ps1 -resourceGroupName $resourceGroupName -location $location -vmName $vmName -imageReferenceId $imageReferenceId
    }

$scriptBlocSqAzurePSUpdateVMSS = {
    param ($tenantId, $subscriptionId, $user, [secureString] $password, $resourceGroupName, $location, $vmssName, $imageReferenceId)
        
        # Update a VM
        . .\sinequa-for-azure-upgrade-vmss-node.ps1 -resourceGroupName $resourceGroupName -location $location -vmssName $vmssName -imageReferenceId $imageReferenceId
    }

# Update VMs
$jobs = @()
foreach ($vm in $vms) {
    $jobName = "Update-$($vm.Name)"   
    $vmName = $vm.Name
    $jobs += Start-Job -Name $jobName -ScriptBlock $scriptBlocSqAzurePSUpdateVM -ArgumentList @($tenantId,$subscriptionId, $user, $password, $resourceGroupName, $location, $vmName, $imageReferenceId)    
    #. .\sinequa-for-azure-upgrade-vm-node.ps1 -resourceGroupName $resourceGroupName -location $location -vmName $vmName -imageReferenceId $imageReferenceId
}
foreach ($vmss in $vmsss) {
    $jobName = "Update-$($vmss.Name)"   
    $vmssName = $vmss.Name
    $jobs += Start-Job -Name $jobName -ScriptBlock $scriptBlocSqAzurePSUpdateVMSS -ArgumentList @($tenantId,$subscriptionId, $user, $password, $resourceGroupName, $location, $vmssName, $imageReferenceId)    
    #. .\sinequa-for-azure-upgrade-vm-node.ps1 -resourceGroupName $resourceGroupName -location $location -vmName $vmName -imageReferenceId $imageReferenceId
}
do {
    $finished = $true
    foreach ($job in $jobs) {
        Receive-Job -Job $job
        $finished = $finished -and ($job.State -eq "Completed")
        Start-Sleep -s 1
    }    
} while (!$finished)

$EndTime = Get-Date
WriteLog "Script execution time: $($EndTime - $StartTime)"