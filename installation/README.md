# Sinequa for Azure - Deploy using agnostic Infrastructure as Code


If you don't want to use the Sinequa PowerShell samples to build the Sinequa version Image or deploy your Sinequa environment in Azure using the Sinequa Terraform samples scripts, you can follow the procedure described bellow.

- [Sinequa for Azure - Deploy using agnostic Infrastructure as Code](#sinequa-for-azure---deploy-using-agnostic-infrastructure-as-code)
- [ Build your Sinequa Version Image](#-build-your-sinequa-version-image)
  - [ Deploy Sinequa distribution](#-deploy-sinequa-distribution)
  - [ Set Windows environment variables](#-set-windows-environment-variables)
  - [ Create Windows Services:](#-create-windows-services)
  - [ Open ports](#-open-ports)
  - [ Generalize VM and Build Image](#-generalize-vm-and-build-image)
- [ Provision Azure Services](#-provision-azure-services)
  - [ Azure - Managed Identity](#-azure---managed-identity)
  - [ Azure - Storage Accounts](#-azure---storage-accounts)
    - [ Create container (Organization)](#-create-container-organization)
    - [ Create Blobs](#-create-blobs)
    - [ Role Assignments](#-role-assignments)
  - [ Azure - VM](#-azure---vm)
    - [ Data Disk](#-data-disk)
    - [ Tags](#-tags)
    - [ User assigned managed identities](#-user-assigned-managed-identities)
  - [ Azure - Key Vault (optional)](#-azure---key-vault-optional)
    - [ Create Blob](#-create-blob)
    - [ Role Assignment](#-role-assignment)
    - [ Add Secrets](#-add-secrets)
  - [ Azure - VM Scale Set (optional)](#-azure---vm-scale-set-optional)
    - [ Tags](#-tags-1)
    - [ User assigned managed identities](#-user-assigned-managed-identities-1)
    - [ Role Assignments](#-role-assignments-1)

<br><br>

# <a name="build_version_image"></a> Build your Sinequa Version Image

The Sinequa version image, is a Windows image on which:
- Sinequa prerequisites are meet
- Sinequa binaries are deployed
- Sinequa windows services are created
- Sinequa Azure specific OS environment variables are created

The list of prerequisites can be found here: [Installing Sinequa ES - Prerequisites](https://doc.sinequa.com/en.sinequa-es.v11/Content/en.sinequa-es.install.windows-server.html#Prerequisites) 

<br>

## <a name="build_version_image_dist"></a> Deploy Sinequa distribution 

Download the latest [Sinequa stable release](https://download.sinequa.com/home). 

We recommend to unzip the Sinequa binaries to the OS drive on the `C:\sinequa\` folder. 

<br>

## <a name="build_version_image_env_vars"></a> Set Windows environment variables

Name | Value | Target | Mandatory | Optional | Comment
--- | --- | --- | --- | --- | --- 
SINEQUA_CLOUD | Azure | Machine | X | | Specify Sinequa Node to run in S4A mode
SINEQUA_LOG_INIT | Path=d:\;Level=10000 | Machine | | X | Set log level of all process before configuration is loaded. Enable Sinequa.cloudinit.service logs for debugging.
SINEQUA_TEMP | d:\sinequa\temp | Machine | | X | Sinequa temp folder. By default the temp folder is located in *&lt;sinequa&gt;/temp*. It's recommended to leverage the local "Temp Storage" (Temp drive) of the VM instead of writing temp files in the distribution folder. Not all the VMs instances type have "Temp Storage", please refer to [Sizes for virtual machines in Azure](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes)

Sinequa For Azure (S4A) documentation: [Cloud Init](https://github.com/sinequa/SinequaForAzure#211-environment-variable--)

**Command Lines:**

Set SINEQUA_CLOUD
> [System.Environment]::SetEnvironmentVariable('SINEQUA_CLOUD', 'Azure',[System.EnvironmentVariableTarget]::Machine)

Set SINEQUA_LOG_INIT (Optional)
> [System.Environment]::SetEnvironmentVariable('SINEQUA_LOG_INIT', 'Path=d:\;Level=10000',[System.EnvironmentVariableTarget]::Machine)

Set SINEQUA_TEMP (Optional)
> [System.Environment]::SetEnvironmentVariable('SINEQUA_TEMP', 'd:\sinequa\temp',[System.EnvironmentVariableTarget]::Machine)

Windows documentation: [Set Environment Variable in Windows operating system registry key](https://learn.microsoft.com/en-us/dotnet/api/system.environment.setenvironmentvariable?view=net-7.0#system-environment-setenvironmentvariable(system-string-system-string-system-environmentvariabletarget))

<br>

## <a name="build_version_image_win_services"></a> Create Windows Services:

Do **NOT** start the Sinequa services at this stage. Services will be started later on, when the VM will be deployed using the image.
Services must be running using a admin account or localsystem account.

Name | Start | BinPath | displayname | obj | Mandatory | Optional | Comment
--- | --- | --- | --- | --- | --- | --- | ---
sinequa.cloudinit.service | delayed-auto | C:\sinequa\bin\sinequa.cloudinit.exe | sinequa.cloudinit.service | | X | | sinequa.cloudinit.service will bootstrap  the VM and then start the sinequa.service
sinequa.service | demand | C:\sinequa\bin\sinequa.service.exe | sinequa.service | NT Authority\NetworkService | X | | sinequa.service start the Sinequa Node on the VM

Command line:

Install sinequa.cloudinit.service

> sc.exe create sinequa.cloudinit.service start=delayed-auto binPath="C:\sinequa\bin\sinequa.cloudinit.exe" DisplayName="sinequa.cloudinit.service"

Install sinequa.service

> sc.exe create sinequa.service start=demand obj="NT Authority\NetworkService" binPath="C:\sinequa\bin\sinequa.service.exe" DisplayName="sinequa.service"

Windows documentation: [Creates a subkey and entries for a service in the registry and in the Service Control Manager database](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/sc-create)


<br>

## <a name="build_version_image_win_ports"></a> Open ports

Open the ports on the VM for Sinequa components (Node, Indexer, WebApp, Engine...)

Sinequa Component | Default Port
--- | --- 
Engine | 10300
Node | 10301
Indexer | 10302
Queue Server | 10303
Store Server | 10305
WebApp HTTP | 80
WebApp HTTPS | 443

<br>

## <a name="build_version_image_gen_build_img"></a> Generalize VM and Build Image

Generalize the VM and build the **Sinequa version Image**. This image will be used when provisioning the VMs or the VM Scale set.

Windows documentation: [Remove machine specific information by generalizing a VM before creating an image
](https://learn.microsoft.com/en-us/azure/virtual-machines/generalize)

<br><br>

# <a name="azure_services"></a> Provision Azure Services

In order to have S4A working you need to provision and configure the following Azure services:

Azure Service | Mandatory | Optional | Comment
--- | --- | --- | --- 
Managed Identity | X | | Used by VMs to access Storage Accounts and Key Vault
Storage Accounts | X | | Two Storage Accounts are required
Key Vault |  | X | Used to store keys, secrets, and certificates
VM Scale Set | | X | Dynamic pool of indexers. If you don't want to use the S4A dynamic indexers feature, you can still use static indexers

<br>

When provisioning the resources, please include the Sinequa Partner Tracking GUID in your scripts.

**Sinequa Partner Tracking GUID**: `947f5924-5e20-4f0a-96eb-808371995ac8`

ARM Documentation: [Add a GUID to a Resource Manager template
](https://learn.microsoft.com/en-us/partner-center/marketplace/azure-partner-customer-usage-attribution#add-a-guid-to-a-resource-manager-template)

Terraform Documentation: [Partner ID a GUID/UUID registered with Microsoft to facilitate partner resource
](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs#partner_id)

<br>

Before going forward, there are two important notion to understand about S4A environment management:

S4A is composed of two virtual layers:
- The **Organization** layer
- The **Environment** layer

An **Organization** is composed of multiple **Environments**. An Environments is a Sinequa Grid (DEV, PROD...)

For example, you might have two Organizations *SinequaEnterpriseSearch* and *SinequaPublicSearch* corresponding two Sinequa projects.
- *SinequaEnterpriseSearch* is the internal Enterprise Search project composed of 4 Environments: DEV, TEST, PREPROD and PROD
- *SinequaPublicSearch* is the public facing search open to the internet composed of 2 Environments: DEV and PROD

These virtual layer will determine how the data is stored on the storage accounts:
- One 'container' per **Organization**
- Each **Environment** will have a dedicated folder in the *grids* folder within the *container*

See more in the [S4A Storage Accounts](#)

The following documentation will demonstrate how to create an organization named **sinequa-enterprise-search** with a single **DEV** environment.

<br>

## <a name="azure_services_identity"></a> Azure - Managed Identity

Create a new *User assigned managed identity*, this identity will be refereed as `{sinequa_user_assigned_identity}`

`{sinequa_user_assigned_identity}` be used by the VMs to access the following resources:
- Primary and Secondary Storage accounts
- Key Vault 
- VM Scale Set

NOTE: You must have only one "user assigned identity" and zero "System assigned identity". Otherwise, the sinequa.cloudinit.service will fail to connect to the storage account(s).

<br>

## <a name="azure_services_sa"></a> Azure - Storage Accounts 

You must provision two Storage Accounts: 'Primary' and 'Secondary' Storage Accounts. 
Sinequa leverage two Storage Accounts to offers better performances and reduce the storage footprint.

Sinequa For Azure (S4A) documentation: 
- [Storage Account](https://github.com/sinequa/SinequaForAzure#22-leverage-storage-account--)
- [Secondary Storage Account](https://github.com/sinequa/SinequaForAzure#23-leverage-a-secondary-storage-account--)

Type | Performance | Premium account type | Comment
--- | --- | --- | --- 
Storage Account | Premium | Block blobs | Primary Storage Account used to store HBlobs (pointers to Blobs located in Secondary Storage)
Storage Account | Standard | - | Secondary Storage Account used to store Blobs

<br>

### <a name="azure_services_sa_container"></a> Create container (Organization)

Once provisioned, you have to create the container (Organization) on **both** storage accounts. The name of the container is free.

Create the two containers with the following name 'sinequa-enterprise-search', which correspond to the name of the Organization

The container (Organization) will be refereed as `{sinequa_org_container}`

<br>

### <a name="azure_services_sa_blobs"></a> Create Blobs

Then, on the **Primary Storage Account**, you must create the following blobs:

Path | Content | Comment
--- | --- | ---
`{sinequa_org_container}`/var/sinequa-secondary <br/> ex: `sinequa-enterprise-search/var/sinequa-secondary` | https://`{secondary_storage_account}`.`{api_doamin}`/`{sinequa_org_container}`  <br/> ex: `https://sinequasecondary.blob.core.windows.net/sinequa-enterprise-search` | Secondary storage definition
`{sinequa_org_container}`/grids/`{environment_name}`/var/sinequa-primary-nodes <br/> ex: `sinequa-enterprise-search/grids/dev/var/sinequa-primary-nodes` | ex: 1=srpc://`{hostname}`:`{node_port}` <br/> `1=srpc://vm1:10301` | Primary Node(s) definition

Sinequa For Azure (S4A) documentation: [Cloud Variables](https://github.com/sinequa/SinequaForAzure#213-cloud-variables--cloud-secrets--)

<br>

### <a name="azure_services_roles"></a> Role Assignments

Link the two Storage Accounts with the `{sinequa_user_assigned_identity}` user identity 

Role | Resource Name | Resource Type | Comment
--- | --- | --- | --- 
Storage Blob Data Contributor | `{primary_storage_account}` | Storage account | Allow identity to read, write and delete blobs
Storage Blob Data Contributor | `{secondary_storage_account}` | Storage account | Allow identity to read, write and delete blobs

<br>

## <a name="azure_services_vm"></a> Azure - VM

When provisioning the VM(s) you need to:
- use the "Sinequa version image"
- Add a data disk
- Set specific Tags
- Link to user identity

### <a name="azure_services_vm_disk"></a> Data Disk

Add a data disk to the VM. The data disk will be used to store persistent data (Sinequa data folder, indexes, logs, WebApp local Data).

Minimum required size is 64GB, recommended type is Premium SSD

### <a name="azure_services_vm_tags"></a> Tags

Tag Name | Tag Value | Mandatory | Optional | Comment
--- | --- | --- | --- | ---
sinequa-data-storage-url | https://`{primary_storage_account_name}`.blob.core.windows.net/<br>`{sinequa_org_container}`/grids/`{environment_name}` <br><br> ex:  `https://sinequaprimary.blob.core.windows.net/`<br>`sinequa-enterprise-search/grids/dev/` | X | | Enable Primary Storage Account
sinequa-node | `{node_name}` <br> ex: node-1 | X | | Node name
sinequa-auto-disk | auto | | X | At VM start, raw disks are automatically partitioned. Mandatory if your image doesn't contains the data disk. sinequa-auto-disk is performed by the sinequa.cloudinit service
sinequa-path | F:\sinequa | | X | Root folder for the Sinequa `data` folder. Default is Sinequa Binaries folder. Recommended to have the data folder on a different drive than the OS drive.
sinequa-primary-node-id | 1 | | X | Only for Primary Node. Note: You need at least one Primary Node


NOTE: Depending on the VM, you might want to enable additional features. Please refer to: Sinequa For Azure (S4A) documentation [Cloud Tags](https://github.com/sinequa/SinequaForAzure#212-cloud-tags--)

For a standalone instance with a WebApp and an Engine you might consider adding the following:

Tag Name | Tag Value |  Comment
--- | --- | --- 
sinequa-engine | `{engine_name}` <br> ex: engine-1 | Engine name
sinequa-kestrel-webapp | `{webapp_name}` <br> ex: webapp-1 | WebApp name
sinequa-webapp-fw-port | 80 | Opens windows firewall port 80 if not done in the image. Firewall is opened by the sinequa.cloudinit service

### <a name="azure_services_vm_identity"></a> User assigned managed identities

You must add the Managed Identity created before so the VM can authenticate to cloud services (Storages Accounts, Key Vault...)

In the VM settings, add the *Managed Identity* `{sinequa_user_assigned_identity}` to the *User Assigned* VM

<br>

## <a name="azure_services_kv"></a> Azure - Key Vault (optional)

Optionally, you can provision a Key Vault that will be used to store  keys, secrets, and certificates. 

Set the *Access policy* to *Azure role-based access control*

### <a name="azure_services_kv_blob"></a> Create Blob

In Primary Storage Account, you must create the following blob:
Path | Content | Comment
--- | --- | ---
`{sinequa_org_container}`/grids/`{environment_name}`/var/sinequa-keyvault <br/> `sinequa-enterprise-search/grids/dev/var/sinequa-keyvault` | `{sinequa_key_vault}` <br/> `sinequakv` | Key Vault reference

### <a name="azure_services_kv_role"></a> Role Assignment

Once the Key Vault is created you must add the *Managed Identity* `{sinequa_user_assigned_identity}` with the *Key Vault Secrets Officer* role

Role | Resource Name | Resource Type | Comment
--- | --- | --- | --- 
Key Vault Secrets Officer | `{sinequa_key_vault}` | Key vault | Perform any action on the secrets of a key vault, except manage permissions

### <a name="azure_services_kv_secret"></a> Add Secrets

Optionally, you can add secrets to the key vault

Sinequa For Azure (S4A) documentation: [Cloud Secrets](https://github.com/sinequa/SinequaForAzure#213-cloud-variables--cloud-secrets--)

For instance, you can add the Sinequa license:
Secret Name | Secret Value | Comment
--- | --- | ---
sinequa-license	| `{Sinequa license}` | String of the Sinequa license. Used to start components
sinequa-default-admin-password	| strong random password | Default Sinequa admin password


<br><br>

## <a name="azure_services_vmss"></a> Azure - VM Scale Set (optional)

Sinequa For Azure (S4A) documentation: [Scale Set for Elasticity](https://github.com/sinequa/SinequaForAzure#scaleset)

### <a name="azure_services_vmss_tags"></a> Tags

Tag Name | Tag Value | Mandatory | Optional | Comment
--- | --- | --- | --- | ---
sinequa-data-storage-url | https://`{primary_storage_account_name}`.blob.core.windows.net/`{sinequa_org_container}`/grids/`{environment_name}` <br> ex:  `https://sinequaprimary.blob.core.windows.net/sinequa-enterprise-search/grids/dev/` | X | | Enable Primary Storage Account
sinequa-node | `{node_name}` <br> ex: node-vmss | X | | Node name
sinequa-indexer | `{dynamic_indexer_name}` | X | | Indexer Names. Use the `{dynamic_indexer_name}` prefix

### <a name="azure_services_vmss_identity"></a> User assigned managed identities

You must add the Managed Identity created before so the VM can authenticate to cloud services (Storages Accounts, Key Vault...)

In the VM Scale Set settings, add the *Managed Identity* `{sinequa_user_assigned_identity}` to the *User Assigned* VM

### <a name="azure_services_vmss_roles"></a> Role Assignments

Role | Resource Name | Resource Type | Comment
--- | --- | --- | --- 
Contributor | `{vm_scale_set}` | Virtual machine scale set | Grants full access to manage the VM Scale Set
