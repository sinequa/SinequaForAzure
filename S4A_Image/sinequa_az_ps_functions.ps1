# ERROR REPORTING ALL 
Set-StrictMode -Version latest;

# Remove WARNING: breaking changes...
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"


$startupScript = $null; #"sinequa-az-startup.ps1"
function SqAzurePSLogin($tenantId, $subscriptionId, $user, [securestring]$password, $servicePrincipalID, [securestring] $servicePrincipalSecret) {
    <#
    .SYNOPSIS
        Login on Azure with login and password
    .PARAMETER tenantId
        Azuez Tenant Id
    .PARAMETER subscriptionId
        Azuez subscription Id
    .PARAMETER user
        User login
    .PARAMETER password
        User password
    #>
    if ($user -and $user.length -gt 0 -and $password -and $password.length -gt 0) 
    {
        $Credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $user,$password
        Connect-AzAccount -Credential $Credential -Tenant $tenantId -Subscription $subscriptionId
    } elseif ($servicePrincipalID -and $servicePrincipalID.length -gt 0 -and $servicePrincipalSecret -and $servicePrincipalSecret.length -gt 0) 
    {
        $pscredential = New-Object -TypeName System.Management.Automation.PSCredential($servicePrincipalID, $servicePrincipalSecret)
        Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $tenantId
    }
    WriteLog "Use Subscription ID: $subscriptionId"
    return Set-AzContext -SubscriptionId $subscriptionId
}

function SqAzurePSCreateTempVM($resourceGroup, $publisherName, $offer, $sku, $image, $prefix, $nodeName, $vmName, $osUsername, [SecureString]$osPassword, $vmSize = "Standard_D4s_v3") {
    <#
    .SYNOPSIS
        Create a VM from an Image or from a default Windows Image
    .PARAMETER resourceGroup
        Resource Group object
    .PARAMETER image
        Azure Image. If empty, will use a default Windows image
    .PARAMETER osUsername
        Username of the Windows User
    .PARAMETER osPassword
        Password of the Windows User
    .PARAMETER vmSize
        Size of the VM. Default = Standard_D4s_v3
    .OUTPUTS
        Virtual Machine object created
    #>
    
    # Variables
    if (!$prefix) { $prefix = "sq-temp"}
    if (!$nodeName) { $nodeName = "0"}
    $SubnetName = "snet-$prefix"
    $SubnetRange = "192.168.1.0/24"
    $VNetName = "vnet-$prefix"
    $VNetRange = "192.168.0.0/16"
    $NSGName = "nsg-$prefix"
    $saName = (New-Guid).toString().Replace('-','').SubString(0,24)
    $hostname = $nodeName
    
    # Create a new storage account to store boot diagonostics & scripts
    $sa = Get-AzStorageAccount -ResourceGroupName $resourceGroup.ResourceGroupName -ErrorAction SilentlyContinue
    if (!$sa) {
        WriteLog "[$($vmName)] Creating storage account: $saName"
        $sa = New-AzStorageAccount -ResourceGroupName $resourceGroup.ResourceGroupName -Name $saName -Location $resourceGroup.Location -SkuName Standard_LRS
    }
    if ($sa -is [array]) {$sa= $sa[0]}

    ## Create network resources
    # Create a subnet configuration
    WriteLog "[$($vmName)] Creating virtual network: $SubnetName"
    $SubnetConfig = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetRange

    # Create a virtual network
    $VirtualNetwork = Get-AzVirtualNetwork -ResourceGroupName $resourceGroup.ResourceGroupName -Name $VNetName -ErrorAction SilentlyContinue
    if (!$VirtualNetwork) {
        $VirtualNetwork = New-AzVirtualNetwork -ResourceGroupName $resourceGroup.ResourceGroupName -Location $resourceGroup.Location -Name $VNetName -AddressPrefix $VNetRange -Subnet $SubnetConfig -Force
    }

    # Create network security group rule (SSH or RDP)
    WriteLog "[$($vmName)] Creating SSH/RDP network security rule"
    $SecurityGroupRule = switch ("-Windows") {
        "-Linux" { New-AzNetworkSecurityRuleConfig -Name "SSH-Rule" -Description "Allow SSH" -Access "Allow" -Protocol "TCP" -Direction "Inbound" -Priority 100 -DestinationPortRange 22 -SourceAddressPrefix "*" -SourcePortRange "*" -DestinationAddressPrefix "*" }
        "-Windows" { New-AzNetworkSecurityRuleConfig -Name "RDP-Rule" -Description "Allow RDP" -Access "Allow" -Protocol "TCP" -Direction "Inbound" -Priority 100 -DestinationPortRange 3389 -SourceAddressPrefix "*" -SourcePortRange "*" -DestinationAddressPrefix "*" }
    }

    # Create a network security group
    WriteLog "[$($vmName)] Creating network security group: $NSGName"
    $NetworkSG = Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup.ResourceGroupName -Name $NSGName -ErrorAction SilentlyContinue
    if (!$NetworkSG) {
        $NetworkSG = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup.ResourceGroupName -Location $resourceGroup.Location -Name $NSGName -SecurityRules $SecurityGroupRule -Force
    }

    ## Create the virtual machine
    SqAzurePSCreateVMforNode `
    -resourceGroup $resourceGroup `
    -storageAccount $sa `
    -createPip $true `
    -prefix $prefix `
    -publisherName $publisherName `
    -offer $offer `
    -sku $sku `
    -image $image `
    -nodeName $nodeName `
    -vmName $vmName `
    -nsg $NetworkSG `
    -subnet $VirtualNetwork.Subnets[0] `
    -osUsername $osUsername `
    -osPassword $osPassword `
    -hostname $hostname
}

function SqAzurePSCreateVMforNode(
    $resourceGroup, 
    $storageAccount, 
    $createPip, 
    $prefix,
    $publisherName = "MicrosoftWindowsServer",
    $offer = "WindowsServer",
    $sku = "2019-Datacenter-smalldisk",
    $image,
    $tags, 
    $nodeName, 
    $hostName, 
    $vmName, 
    $nsg, 
    $subnet, 
    $osUsername, 
    [SecureString]$osPassword, 
    $vmSize = "Standard_D4s_v3", 
    $dataDiskSizeInGB
    ) {
    <#
    .SYNOPSIS
        Create a VM from an Image or from a default Windows Image
    .PARAMETER resourceGroup
        Resource Group object
    .PARAMETER image
        Azure Image. If empty, will use a default Windows image
    .PARAMETER osUsername
        Username of the Windows User
    .PARAMETER osPassword
        Password of the Windows User
    .PARAMETER vmSize
        Size of the VM. Default = Standard_D4s_v3
    .OUTPUTS
        Virtual Machine object created
    #>
    
    # Variables
    $pipName = "pip-$prefix-$nodeName"
    $nicName = "nic-$prefix-$nodeName"

    #default windows image (Microsoft Windows 2019 Datacenter)
    $imageName = $offer
    if ($image) {
        $imageName = $image.Name
    }
    $osDiskName = "osdisk-$($prefix)_$($nodeName)-$($imageName)"
    $osDiskSize = 64
    $dataDiskName = "datadisk-$($prefix)_$($nodeName)"
    $dataDiskType = "Premium_LRS" #"Premium_LRS"
    if (!$vmName) {$vmName = "vm-$prefix-$nodeName"}
    if (!$hostName) {$hostName =  "$prefix-$nodeName"}

  
    
    #default tag
    if (!$tags) {
        $tags = @{Sinequa_Image=$imageName}
    } else {
        $tags.Add('Sinequa_Image', $imageName)
    }
    # Create a public IP address
    $pip = $null
    $pipId = $null
    if ($createPip) {
        WriteLog "[$($vmName)] Creating public IP address: $pipName"
        $pip = New-AzPublicIpAddress -ResourceGroupName $resourceGroup.ResourceGroupName-Location $resourceGroup.Location -AllocationMethod "Dynamic" -Name $pipName -Tag @{Sinequa_Grid=$prefix} -Force
        $pipId = $pip.Id
    }

    # Create a virtual network card and associate it with the public IP address and NSG
    WriteLog "[$($vmName)] Creating network interface card: $nicName"    
    $nic = New-AzNetworkInterface -Name $nicName -ResourceGroupName $resourceGroup.ResourceGroupName-Location $resourceGroup.Location -SubnetId $subnet.Id -PublicIpAddressId $pipId -NetworkSecurityGroupId $nsg.Id -Tag @{Sinequa_Grid=$prefix} -Force

    # Define a credential object to store the username and password for the virtual machine
    $credential = New-Object -TypeName PSCredential -ArgumentList ($osUsername, $osPassword)

    # Create the virtual machine configuration object
    $vm = New-AzVMConfig -VMName $vmName -VMSize $vmSize -IdentityType SystemAssigned

    # Set the VM Size and Type
    $null = Set-AzVMOperatingSystem -VM $vm -Windows -ComputerName $hostName -Credential $credential

    # Enable the provisioning of the VM Agent
    if ($vm.OSProfile.WindowsConfiguration) {
        $vm.OSProfile.WindowsConfiguration.ProvisionVMAgent = $true
    }

    # Set the VM Source Image
    if ($image) {
        WriteLog "[$($vmName)] Use Image ($($image.Id)) for virtual machine"
        $null = Set-AzVMSourceImage -VM $vm -Id $image.Id 
    } else {
        WriteLog "[$($vmName)] Use default $offer $sku Image for virtual machine"
        $null = Set-AzVMSourceImage -VM $vm -PublisherName $publisherName -Offer $offer -Skus $sku -Version latest
    }

    # Add Network Interface Card
    $null = Add-AzVMNetworkInterface -Id $nic.Id -VM $vm

    # Applies the OS disk properties
    $null = Set-AzVMOSDisk -VM $vm -CreateOption FromImage -Name $osDiskName -DiskSizeInGB $osDiskSize

    # Add a DataDisk
    if ($dataDiskSizeInGB) {
        WriteLog "[$($vmName)] Create Datadisk: $dataDiskName ($dataDiskSizeInGB Gb)"
        #$diskConfig = New-AzDiskConfig -SkuName $dataDiskType -Location $resourceGroup.Location -CreateOption Empty -DiskSizeGB $dataDiskSizeInGB
        #$dataDisk = New-AzDisk -DiskName $dataDiskName -Disk $diskConfig -ResourceGroupName $resourceGroup.ResourceGroupName
        $null = Add-AzVMDataDisk -VM $vm -Name $dataDiskName -CreateOption Empty -Caching 'ReadOnly' -Lun 1 -DiskSizeInGB $dataDiskSizeInGB -StorageAccountType $dataDiskType
    }

    # Set the boot diagnostics storage account
    $null = Set-AzVMBootDiagnostic -VM $vm -Enable -ResourceGroupName $resourceGroup.ResourceGroupName -StorageAccountName $storageAccount.StorageAccountName

    # Create the virtual machine.
    WriteLog "[$($vmName)] Creating virtual machine: $vmName"
    $vm = New-AzVM -ResourceGroupName $resourceGroup.ResourceGroupName -Location $resourceGroup.Location -VM $vm -Verbose -Tag $tags
}

function SqAzurePSCreateVMSSforNode($resourceGroup, $storageAccount, $prefix, $image, $tags, $nodeName, $hostName, $vmssName, $nsg, $subnet, $osUsername, [SecureString]$osPassword, $vmSize = "Standard_D4s_v3") {
    <#
    .SYNOPSIS
        Create a VM ScaleSet from an Image or from a default Windows Image
    .PARAMETER resourceGroup
        Resource Group object
    .PARAMETER image
        Azure Image. If empty, will use a default Windows image
    .PARAMETER osUsername
        Username of the Windows User
    .PARAMETER osPassword
        Password of the Windows User
    .PARAMETER vmSize
        Size of the VM. Default = Standard_D4s_v3
    .OUTPUTS
        Virtual Machine object created
    #>
    
    # Variables
    if (!$vmssName) {$vmssName = "vmss-$prefix-$nodeName"}
    $osNamePrefix = "$prefix-$nodeName"
    if ($hostname) {
        $osNamePrefix = $hostName
    } 
    if ($osNamePrefix.Length -gt 8) {$osNamePrefix = $osNamePrefix.SubString(0,8)}

    #default tag
    if (!$tags) {
        $tags = @{Sinequa_Image=$image.Name}
    } else {
        $tags.Add('Sinequa_Image', $image.Name)
    }

    # Create IP address configurations
    $ipConfig = New-AzVmssIpConfig -Name "vmssIPConfig" -SubnetId $subnet.Id

    # Create a configuration  
    $vmss = New-AzVmssConfig -Location $resourceGroup.Location -IdentityType SystemAssigned -SkuCapacity 2 -SkuName $vmSize -UpgradePolicyMode "Automatic" -Tag $tags
    
    # Reference the image version
    WriteLog "[$($vmssName)] Reference the image version: $($image.Id)"
    $null = Set-AzVmssStorageProfile $vmss -OsDiskCreateOption "FromImage" -ImageReferenceId $image.Id

    # Complete the configuration
    $null = Add-AzVmssNetworkInterfaceConfiguration -VirtualMachineScaleSet $vmss -Name "network-config" -Primary $true -IPConfiguration $ipConfig 

    $null = Set-AzVmssOSProfile -VirtualMachineScaleSet $vmss -ComputerNamePrefix $osNamePrefix -AdminUsername $osUsername -AdminPassword $osPassword

    # Create the scale set 
    WriteLog "[$($vmssName)] Creating virtual machine ScaleSet: $vmssName"
    $null = New-AzVmss -ResourceGroupName $resourceGroup.ResourceGroupName -Name $vmssName -VirtualMachineScaleSet $vmss -Verbose
}

function SqAzurePSRunScriptFromStorageAccount($resourceGroupName, $vmName, $storageAccountName, $saKey, $containerName, $scriptName, $scriptArguments) {
    <#
    .SYNOPSIS
        Run a script as a Custom Script Extention (cse) from a Storage Account
    .PARAMETER resourceGroupName
        Resource Group Name
    .PARAMETER vmName
        Virtual Machine Name on which the script will be executed
    .PARAMETER storageAccountName
        Storage Account which contains the script
    .PARAMETER saKey
        Storage Account Access Key
    .PARAMETER containerName
        Container which contains the script
    .PARAMETER scriptName
        Script to execute
    .PARAMETER scriptArguments
        Arguments of the script
    .OUTPUTS
        VirtualMachineCustomScriptExtensionContext
    #>

    WriteLog "[$($vmName)] Running the script '$($scriptName)' on the '$vmName' VM"

    Set-AzVMCustomScriptExtension -ContainerName $containerName `
    -FileName $scriptName `
    -Location $location `
    -Name $scriptName `
    -ResourceGroupName $resourceGroupName `
    -Run $scriptName `
    -Argument $scriptArguments `
    -StorageAccountKey $sakey `
    -StorageAccountName $storageAccountName `
    -VMName $VMName

    $cs = Get-AzVMCustomScriptExtension -ResourceGroupName $resourceGroupName -VMName $vmName -Name $scriptName -Status
    return $cs
}


function SqAzurePSRunScript($resourceGroupName, $vmName, $scriptName, $parameters) {
    <#
    .SYNOPSIS
        Run a Custom script
    .PARAMETER resourceGroupName
        Resource Group Name
    .PARAMETER vmName
        Virtual Machine Name on which the script will be executed
    .PARAMETER scriptName
        Script to execute
    .PARAMETER parameters
        Parameters of the script
    .OUTPUTS
    #>
 
    WriteLog "[$($vmName)] Running the script '$($scriptName)' on the '$vmName' VM"
    $result = Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -Name $vmName -CommandId "RunPowerShellScript" -ScriptPath $scriptName -Parameter $parameters
        
    $output = $result | Select-Object -expand Value 
    $stdOut = $output | Where-Object {$_.Code -eq "ComponentStatus/StdOut/succeeded"} | Select-Object Message
    $stdErr = $output | Where-Object {$_.Code -eq "ComponentStatus/StdErr/succeeded"} | Select-Object Message

    if ($stdOut -and $stdOut.Message.length -gt 0) {
        WriteLog "[$($vmName)] $($stdOut.Message)"
    }
    if ($stdErr -and $stdErr.Message.length -gt 0) {
        WriteError "[$($vmName)] $($stdErr.Message)"
    }
    if ($result.Status -ne "Succeeded") {
        WriteError("[$($vmName)] Command failed")
        Exit 1
    }
    if ($stdErr.Message.length -gt 0) {
        WriteError("[$($vmName)] Command failed")
        Exit 1
    }
}

function SqAzurePSApplyWindowsUpdates($resourceGroupName, $vmName, $scriptName) {
    <#
    .SYNOPSIS
        Run a Windows Update script
    .PARAMETER resourceGroupName
        Resource Group Name
    .PARAMETER vmName
        Virtual Machine Name on which the script will be executed
    .PARAMETER scriptName
        Script to execute
    .OUTPUTS
    #>
 
    do {
        WriteLog "[$($vmName)] Running Windows Update on the VM"
        $cmd = Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -Name $vmName -CommandId 'RunPowerShellScript' -ScriptPath $scriptName
        
        #Analyze output to know if reboot is needed
        $reboot = $cmd | Select-Object -expand Value |  Where-Object Message -Like '*Reboot*' 
        WriteLog "[$($vmName)] Result of $($scriptName):"
        $reboot

        if ($reboot) {
            WriteLog "[$($vmName)] Restart Windows"
            $null = Restart-AzVM -ResourceGroupName $resourceGroupName -Name $vmName
            Start-Sleep -s 60
        }
    }
    while ($reboot)
}

function WriteLog ($message) {
    <#
    .SYNOPSIS
        Write a Log Message with Timestamp
    .PARAMETER message
        Message to log in console
    #>
    $date = (Get-Date).toString("yyyy-MM-dd hh:mm:ss") 
    Write-Host "$date $message"
}

function WriteError ($message) {
    <#
    .SYNOPSIS
        Write a Error Log Message with Timestamp
    .PARAMETER message
        Message to log in console
    #>
    $date = (Get-Date).toString("yyyy-MM-dd hh:mm:ss") 
    Write-Host "$date $message" -ForegroundColor red 
}

function SqAzurePSCreateImage($resourceGroupName, $imageName, $vm) {
    <#
    .SYNOPSIS
        Create an Image from a VM
    .PARAMETER resourceGroupName
        Resource Group Name
    .PARAMETER imageName
        Image Name
    .PARAMETER vm
        Vm to Image
    .OUTPUTS
        Image
    #>

    # Stop the VM used for the image
    WriteLog "Stop virtual machine: $($vm.Name)"
    $null = Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force

    # Set the VM to generalized status
    WriteLog "Set the VM to generalized status"
    $null = Set-AzVm -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Generalized

    #Remove Image if exists
    $image = Get-AzImage -ResourceGroupName $resourceGroupName -ImageName $imageName -ErrorAction SilentlyContinue
    if ($image) {
        WriteLog "Remove existing Image: $imageName"
        $null = Remove-AzImage -ResourceGroupName $resourceGroupName -ImageName $imageName -Force;
    }

    #Create the image configuration
    $imageCfg = New-AzImageConfig -SourceVirtualMachineId $vm.Id -Location $vm.Location

    #Create the generalized image
    WriteLog "Create Image: $imageName"
    return New-AzImage -Image $imageCfg -ImageName $imageName -ResourceGroupName $resourceGroupName
}

function SqAzGetImageByRefId($referenceId, $context){
    <#
    .SYNOPSIS
        Get an Image by its Id
    .PARAMETER referenceId
        Reference Id of the image
    .PARAMETER context
        image Context (login)
    .OUTPUTS
        Image
    #>

    #"/subscriptions/05cdfb61-fbbb-43a9-b505-cd1838fff60e/resourceGroups/Product/providers/Microsoft.Compute/galleries/SinequaForAzure/images/sinequa-11-nightly"
    #"/subscriptions/05cdfb61-fbbb-43a9-b505-cd1838fff60e/resourceGroups/Product/providers/Microsoft.Compute/images/sinequa-nightly-11.5.1.45",    
    $a = $referenceId.Split("/")
    $image = $null
    if ($a.length -ge 9)
    {
        #$subscriptionId = $a[2]
        $resourceGroupName = $a[4]
        $type = $a[7]
        if ($type.ToLower() -eq "galleries") {
            $galleryName =  $a[8]
            $imageDefName =  $a[10]
            $imageDefVersion = $null
            if ($a.length -ge 12) { $imageDefVersion = $a[11] }
            $image = Get-AzGalleryImageVersion -DefaultProfile $context -ResourceGroupName $resourceGroupName -GalleryName $galleryName -GalleryImageDefinitionName $imageDefName -GalleryImageVersionName $imageDefVersion
            if ($image -is [array]) {$image= $image  | Sort-Object -Property @{Expression={[int][RegEx]::Match($_.Name, "([0-9]+)\.([0-9]+)\.([0-9]+)$").Groups[1].value}},@{Expression={[int][RegEx]::Match($_.Name, "([0-9]+)\.([0-9]+)\.([0-9]+)$").Groups[2].value}},@{Expression={[int][RegEx]::Match($_.Name, "([0-9]+)\.([0-9]+)\.([0-9]+)$").Groups[3].value}} | Select-Object -Last 1}
            return $image
        } elseif ($type.ToLower() -eq "images") {
            $imageName = $a[8]
            $image = Get-AzImage -ImageName $imageName
        }        
    }
    if (!$image) { WriteError "$referenceId not found"}
    return $image
}

function SqAzurePSCreateImageVersion($resourceGroup, $galleryName, $imageDefinitionName, $version, $image) {
    <#
    .SYNOPSIS
        Create an Image Version in a Gallery from an image
    .PARAMETER resourceGroup
        Resource Group Object
    .PARAMETER galleryName
        Gallery Name
    .PARAMETER imageDefinitionName
        Image Definition Name
    .PARAMETER version
        Sinequa version
    .PARAMETER image
        Image to publish
    .OUTPUTS
        GalleryImageVersion
    #>
    
    #Remove Version if exist
    WriteLog "Remove Version (if exists): $version"
    Remove-AzGalleryImageVersion `
    -GalleryImageDefinitionName $imageDefinitionName `
    -Name $version.Substring(3) `
    -GalleryName $galleryName `
    -ResourceGroupName $resourceGroup.ResourceGroupName `
    -Force

    #Create a new version for the image
    WriteLog "Create Image Version: $version"
    $region1 = @{Name="westeurope";ReplicaCount=1}
    $region2 = @{Name="francecentral";ReplicaCount=1}
    $targetRegions = @($region1,$region2)
    $expiration = ((Get-Date).AddYears(1)).ToString("yyyy-MM-dd")

    return New-AzGalleryImageVersion `
    -GalleryImageDefinitionName $imageDefinitionName `
    -GalleryImageVersionName $version.Substring(3) `
    -GalleryName $galleryName `
    -ResourceGroupName $resourceGroup.ResourceGroupName `
    -Location $resourceGroup.Location `
    -TargetRegion $targetRegions `
    -SourceImageId $image.Id `
    -PublishingProfileEndOfLifeDate $expiration    
}

function SqAzurePSLocalFileToRGStorageAccount($resourceGroup, $imageName, $localFile) {
    <#
    .SYNOPSIS
        Upload a local file to a storage account and return its url
    .PARAMETER resourceGroup
        Resource Group Object
    .PARAMETER localFile
        Local File
    .OUTPUTS
        URL from the storage account
    #>
    $saName = (New-Guid).toString().Replace('-','').SubString(0,24)
    $saContainerName = "build"

    # Get Storage Account & Container
    $sa = Get-AzStorageAccount -ResourceGroupName $resourceGroup.ResourceGroupName | Where-Object {$_.Tags['sinequa'] -eq $imageName} -ErrorAction SilentlyContinue
    if (!$sa) {
        WriteLog "Creating storage account: $saName"
        $sa = New-AzStorageAccount -ResourceGroupName $tempResourceGroupName -Name $saName -Location $resourceGroup.Location -SkuName Standard_LRS -Tag @{sinequa=$imageName}
    }    
    $sakey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroup.ResourceGroupName -Name $sa.StorageAccountName)[0].Value;
    $saConnectionString = "DefaultEndpointsProtocol=https;AccountName=$($sa.StorageAccountName);AccountKey=$($sakey);EndpointSuffix=core.windows.net"# 
    $saContext = New-AzStorageContext -ConnectionString $saConnectionString
    $container = Get-AzStorageContainer -Name $saContainerName -Context $saContext -ErrorAction SilentlyContinue
    if (!$container) {
        $container = New-AzStorageContainer -Name $saContainerName -Context $saContext
    }

    # Upload File
    WriteLog "Upload $localFile in $($sa.StorageAccountName)/$saContainerName"
    $filename = (Split-Path -Path $localFile -leaf)
    Set-AzStorageBlobContent -File $localFile -Blob $filename -Container $saContainerName -Context $saContext -Force 
    $sasStartTime = (Get-Date).AddDays(-1)
    $sasEndTime = $sasStartTime.AddDays(2)
    $sasToken = New-AzStorageContainerSASToken -Container $saContainerName -Permission "rl" -StartTime $sasStartTime -ExpiryTime $sasEndTime -Context $saContext
    $url = "https://$($sa.StorageAccountName).blob.core.windows.net/$($saContainerName)/$($filename)$($sasToken)"
    WriteLog "Url: $url"
    return $url
}

function  SqAzurePSGetSecret($keyVaultName, $secretName) {
    <#
    .SYNOPSIS
        Get A Secret value in KeyVault
    .PARAMETER keyVaultName
        KeyVauly Name
    .PARAMETER secretName
        Secret
    .OUTPUTS
        Secret Value
    #>
    $secret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName
    $secretValueText ="";
    $ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret.SecretValue)
    try {
        $secretValueText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)
    } finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)
    }
    return $secretValueText
}

function SqAzurePSGetTagsFromGrid($vms, $vmsss) {
    <#
    .SYNOPSIS
        Get and Generate Tags from an existing grid
    .PARAMETER vms
        List of VMs in the Grid
    .PARAMETER vmsss
        List of VMSSs in the Grid
    .OUTPUTS
        Tags
    #>

    # Retrieve Infos
    $sinequaKeyVault = ""
    $sinequaPrimaryNodes =""
    $sinequaGrid = ""
    $vmCount = 0
    $vmssCount = 0
    if ($vms) {
        foreach ($vm in $vms) {
            $kv = $vm.Tags["Sinequa_KeyVault"]
            if (!$kv) {WriteError("$($vm.Name) is not well configured. Sinequa_KeyVault tag is missing."); Exit 1}
            if ($sinequaKeyVault.Length -gt 0 -and $kv -ne $sinequaKeyVault) {WriteError("$($vm.Name) is not in the same grid of others. Sinequa_KeyVault is different."); Exit 1}
            $sinequaKeyVault = $kv

            $grid = $vm.Tags["Sinequa_Grid"]
            if (!$grid) {WriteError("$($vm.Name) is not well configured. Sinequa_Grid tag is missing."); Exit 1}
            if ($sinequaGrid.Length -gt 0 -and $grid -ne $sinequaGrid) {WriteError("$($vm.Name) is not in the same grid of others. Sinequa_Grid is different."); Exit 1}
            $sinequaGrid = $grid

            $pn = $vm.Tags["Sinequa_PrimaryNodes"]
            if (!$pn) {WriteError("$($vm.Name) is not well configured. Sinequa_PrimaryNodes tag is missing."); Exit 1}
            if ($sinequaPrimaryNodes.Length -gt 0 -and $pn -ne $sinequaPrimaryNodes) {WriteError("$($vm.Name) is not in the same grid of others. Sinequa_KeyVault is different."); Exit 1}
            $sinequaPrimaryNodes = $pn
        }
        $vmCount = $vms.Length
    }
    if ($vmsss) {
        foreach ($vmss in $vmsss) {
            $kv = $vmss.Tags["Sinequa_KeyVault"]
            if (!$kv) {WriteError("$($vmss.Name) is not well configured. Sinequa_KeyVault tag is missing."); Exit 1}
            if ($sinequaKeyVault.Length -gt 0 -and $kv -ne $sinequaKeyVault) {WriteError("$($vmss.Name) is not in the same grid of others. Sinequa_KeyVault is different."); Exit 1}
            $sinequaKeyVault = $kv

            $grid = $vmss.Tags["Sinequa_Grid"]
            if (!$grid) {WriteError("$($vmss.Name) is not well configured. Sinequa_Grid tag is missing."); Exit 1}
            if ($sinequaGrid.Length -gt 0 -and $grid -ne $sinequaGrid) {WriteError("$($vmss.Name) is not in the same grid of others. Sinequa_Grid is different."); Exit 1}
            $sinequaGrid = $grid

            $pn = $vmss.Tags["Sinequa_PrimaryNodes"]
            if (!$pn) {WriteError("$($vmss.Name) is not well configured. Sinequa_PrimaryNodes tag is missing."); Exit 1}
            if ($sinequaPrimaryNodes.Length -gt 0 -and $pn -ne $sinequaPrimaryNodes) {WriteError("$($vmss.Name) is not in the same grid of others. Sinequa_KeyVault is different."); Exit 1}
            $sinequaPrimaryNodes = $pn
        }
        $vmssCount = $vmsss.Length
    }

    $count = $vmCount + $vmssCount
    if ($count -eq 0) {
        WriteLog "Found 0 node(s) in the Sinequa Grid"
        return $null
    }
    
    WriteLog "Found $($count) node(s) in the Sinequa Grid"
    $tags = @{
        Sinequa_KeyVault = $sinequaKeyVault
        Sinequa_Grid = $sinequaGrid
        Sinequa_PrimaryNodes = $sinequaPrimaryNodes
    }
    return $tags
}

function SqAzurePSUpdateVM($resourceGroupName, $location, $vmName, $image, $startupScript) {
    $StartVmTime = Get-Date

    # Get VM to Update
    $vm = Get-AzVm -Name $vmName -ResourceGroupName $resourceGroupName   
    $sinequaKeyVault = $vm.tags.Sinequa_KeyVault
    $sinequaGrid = $vm.tags.Sinequa_Grid
    $sinequaNode = $vm.tags.Sinequa_Node

    $nodeName = "0"
    $pattern = "$($sinequaGrid)-(.*)$"         
    $m =  $vm.Name | Select-String -Pattern $pattern
    if ($m) { $nodeName = $m.Matches.Groups[1].Value }
    $osDiskName = "osdisk-$($sinequaGrid)_$($nodeName)-$($image.Name)"
    $osName = $sinequaNode

    # Get KeyVault for os user/password
    # Get Keyvaul for os user/password
    $userId = (Get-AzContext).Account.Id
    $roleDefinitionName = "Key Vault Secrets User"
    WriteLog "Read secrets in $sinequaKeyVault"
    WriteLog "Requires the Key '$roleDefinitionName' role on $($resourceGroupName) for $userId"
    $role = Get-AzRoleAssignment -ResourceGroupName $resourceGroupName -SignInName  $userId -RoleDefinitionName $roleDefinitionName
    $role
    if (-Not $role) {
        WriteLog "Add transient '$roleDefinitionName' role on $($resourceGroupName) for $userId"
        $null = New-AzRoleAssignment -ResourceGroupName $resourceGroupName -SignInName  $userId -RoleDefinitionName $roleDefinitionName
        Start-Sleep -s 15
    }
    $null = Get-AzRoleAssignment -ResourceGroupName $resourceGroupName -SignInName  $userId -RoleDefinitionName $roleDefinitionName
    $osUsername = SqAzurePSGetSecret -keyVaultName $sinequaKeyVault -secretName "os-username"
    $osPassword = SqAzurePSGetSecret -keyVaultName $sinequaKeyVault -secretName "os-password" | ConvertTo-SecureString -Force -AsPlainText
    if (-Not $role) {
        WriteLog "Remove transient '$roleDefinitionName' role on $($resourceGroupName) for $userId"
        $null = Remove-AzRoleAssignment -ResourceGroupName $resourceGroupName -SignInName  $userId -RoleDefinitionName $roleDefinitionName -ErrorAction SilentlyContinue   
    }

    # Get Original Disk
    $srcDiskName = $vm.StorageProfile.OsDisk.Name

    # Create a new VM config
    $newVmName = "$($vmName)-upg"
    $newVm = New-AzVMConfig -VMName $newVmName -VMSize $vm.HardwareProfile.VmSize -Tags $vm.Tags
    
    # Create a virtual network card and associate it with the public IP address and NSG
    $newNicName = "nic-$newVmName"
    WriteLog "[$($vmName)] Creating network interface card: $newNicName"    
    $nic = Get-AzNetworkInterface -ResourceGroupName $resourceGroupName | Where-Object {$_.VirtualMachine} | Where-Object {$_.VirtualMachine.Id -match ".*$($vmName)$"}
    $newNic =  New-AzNetworkInterface -Name $newNicName -ResourceGroupName $resourceGroupName -Location $location -SubnetId $nic.IpConfigurations[0].Subnet.Id -NetworkSecurityGroupId $nic.NetworkSecurityGroup.Id -Force

    # Add Network Interface Card
    $null = Add-AzVMNetworkInterface -Id $newNic.Id -VM $newVm

    # Set the VM Source Image
    WriteLog "[$($vmName)] Use Image ($($image.Id)) for virtual machine"
    $null = Set-AzVMSourceImage -VM $newVm -Id $image.Id 

    # Applies the OS disk properties
    $null = Set-AzVMOSDisk -VM $newVm -CreateOption FromImage -Name $osDiskName

    # Define a credential object to store the username and password for the virtual machine
    $credential = New-Object -TypeName PSCredential -ArgumentList ($osUsername, $osPassword)

    # Set the VM Size and Type
    $null = Set-AzVMOperatingSystem -VM $newVm -Windows -ComputerName $osName -Credential $credential

    #Stop the VM used for the image
    WriteLog "[$($vm.Name)] Stop virtual machine: $($vm.Name)"
    $null = Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force
    
    # Create the new virtual machine
    WriteLog "[$($vm.Name)] Create new virtual machine: $($newVM)"
    $null = New-AzVM -ResourceGroupName $ResourceGroupName -Location $location -VM $newVM

    # Remove Temp VM
    WriteLog "[$($vm.Name)] Removing Virtual Machine: $($newVmName)"
    $null = Remove-AzVM -ResourceGroupName $resourceGroupName -Name $newVmName -Force
    $null = Remove-AzNetworkInterface -ResourceGroupName $resourceGroupName -Name $newNicName -Force

    # Attach the new disk to the VM
    WriteLog "[$($vm.Name)] Attach $($osDiskName) to $($vmName)"
    $dstDisk = Get-AzDisk -ResourceGroupName $resourceGroupName -Name $osDiskName
    $null = Set-AzVMOSDisk -VM $vm -ManagedDiskId $dstDisk.Id -Name $osDiskName

    # Update Tags
    WriteLog "[$($vm.Name)] Set Tag Sinequa_Image=$($image.Name)"
    if ($vm.Tags["Sinequa_Image"]) {
        $vm.Tags["Sinequa_Image"] = $image.Name
    } else {
        $vm.Tags.Add("Sinequa_Image",$image.Name)
    }

    # Update the VM with the new OS disk
    WriteLog "[$($vm.Name)] Update VM Config of $($vm.Name)"
    $null = Update-AzVM -ResourceGroupName $resourceGroupName -VM $vm
    
    # Start the Updated VM
    WriteLog "[$($vm.Name)] Start Orginal Virtual Machine: $($vm.Name)"
    $null = Start-AzVM -ResourceGroupName $resourceGroupName -Name $vm.Name
    
    # Re-Initialize VM - Run startup script
    if ($startupScript) {
        WriteLog "[$($vm.Name)] Run '$startupScript' script"
        SqAzurePSRunScript -ResourceGroupName $resourceGroupName -VMName $vm.Name -scriptName $startupScript
    }
   
    # Delete old disk
    WriteLog "[$($vm.Name)] Remove original disk '$srcDiskName'"
    $null = Remove-AzDisk -ResourceGroupName $resourceGroupName -DiskName $srcDiskName -Force;
    
    $EndVmTime = Get-Date
    WriteLog "[$($vm.Name)] Execution time for $($vm.Name): $($EndVmTime - $StartVmTime)"
}

