# Sinequa For Azure (S4A)

Sinequa For Azure (S4A) is a set of Capabilities and Dedicated Features designed for Azure.

#### Table of Contents
1. [Repository Content](#content)<br>
2. [Sinequa Azure Features](#features)<br>
2.1. [Cloud Init](#cloudinit)<br>
2.2. [Leverage Storage Account](#storageaccount)<br>
2.3. [Leverage Scale Set for Elasticity](#scaleset)<br>
2.4. [Back Up and Restore the Application](#backup)<br>
  
## 1. Repository Content <a name="content">

This repository contains:
* **[Powershell](./S4A_Image)** scripts to **build your own Sinequa image**
* **[ARM](./ARM)** templates samples to **deploy a Sinequa grid**
* **[Terraform](./terraform)** samples to **deploy a Sinequa grid**

![Sinequa For Azure](images/S4A.png)


## 2. Sinequa Azure Features <a name="features">

### 2.1. Cloud Init <a name="cloudinit">

The `Cloud Init` features are some capabilities used upon VM deployment to initialize an out-of-the-box Sinequa node that is automaticaly registered into a grid with some roles enabled (like engine, indexer, etc.).


#### 2.1.1. Environment Variable <a name="envvars">

The **SINEQUA_CLOUD** `Environment Variable` must be set before starting the Sinequa service for enabling **Cloud Init** Features.

| Name                     | Value                                | Description                          |
| ------------------------ | ------------------------------------ | ------------------------------------ |
|	SINEQUA_CLOUD            | "Azure"                              | Enable Cloud Init features.          |


#### 2.1.2. Cloud Tags <a name="cloudtags">

`Cloud Tags` are Azure Tags used on Azure resources. They are used to run some specific init tasks for a particular VM or VMSS. 

| Name                     | Value Example                        | Description                          |
| ------------------------ | ------------------------------------ | ------------------------------------ |
|	sinequa-data-storage-url | https://`{storage account name}`.blob.core.windows.net/`{container}` | Used to enable storage of:<br>* Configuration<br>* User Settings<br>* Document Cache<br>* Log Store<br>* Audit Store<br>and to declare `Cloud Vars` <br>(see bellow).|
| sinequa-auto-disk         | "auto" or JSON value                | When adding datadisks to an Azure VM, they are not partitioned/formatted. If you select "auto", all raw disks are automaticaly enabled. |
|	sinequa-path		          | "f:\sinequa".  Default is `distrib_path` | `sinequa-path` is the root folder for all customer data, as opposed to `distrib-path` that only contains binaries on the OS disk. `sinequa-path` should be located on a dedicated Azure DataDisk. |
|	sinequa-index-path	      | "g:\sinequa". Optional. Default is sinequa-path | `sinequa-index-path` is the root folder for all indexes. It is recommended to use it for NVMe disks. | 
|	sinequa-node              | "node1"                             | Node name. |
| sinequa-primary-node-id   | 1 (or 2 or 3 or empty)              | To be used on primary nodes. |
|	sinequa-webapp 		        | "webapp1"                           | Name of the WebApp to be created and started on this node.  |
|	sinequa-engine		        | "engine1"                           | Name of the engine to be created and started on this node.  |
|	sinequa-indexer		        | "indexer1"                          | Name of the indexer to be created and started on this node. |


#### 2.1.3. Cloud Vars & Cloud Secrets <a name="cloudvars">

* `Cloud Vars` are `Azure blobs` stored in the `Storage Account`. They are used to declare global variables in the configuration.
* `Cloud Secrets` are `secrets` stored in the `Key Vault` defined in `Cloud Vars`. They are used to store sensitive data.

| Name                                    | Cloud Var | Cloud Secret | Value Example                        | Description                          |
| --------------------------------------- | --------- | ------------ | ------------------------------------ | ------------------------------------ |
|	sinequa-primary-nodes                   | x         |              | "1=srpc://vm-node1:10300;2=srpc://vm-node2:10300;3=srpc://vm-node3=10300" | sRPC connection string of primary nodes. |
| sinequa-keyvault 	                      | x         |              | "kv-grid1"                           | Name of the Key Vault containing secrets (see bellow). |
| sinequa-queue-cluster 	                | x         |              | "QueueCluster1(vm-node1,vm-node2,vm-node3)" | Creates and starts a QueueCluster. |
| sinequa-encryption-key                  | x         | x            | xxxxx                                | Encryption key (see https://doc.sinequa.com/en.sinequa-es.v11/Content/en.sinequa-es.how-to.encrypt.html#generating-encryption-key) |
|	sinequa-license		                      | x         | x            | xxxxx                                | Sinequa license. |
|	sinequa-ssl-force                       | x         | x            | true or false                        | Forces SSL on sRPC. |
|	sinequa-ssl-roots-pem-file              | x         | x            |                                      | pem file for sRPC. |
|	sinequa-ssl-server-ca-crt               | x         | x            |                                      | ca crt file for sRPC. |
|	sinequa-ssl-server-crt                  | x         | x            |                                      | Server crt file for sRPC. |
|	sinequa-ssl-server-key                  | x         | x            |                                      | Server private key for sRPC. |
|	sinequa-ssl-client-certificate-check    | x         | x            |                                      | Client certificate check for sRPC. |
|	sinequa-ssl-client-ca-crt               | x         | x            |                                      | Client ca crt file for sRPC. |
|	sinequa-ssl-client-crt                  | x         | x            |                                      | Client crt file for sRPC. |
|	sinequa-ssl-client-key                  | x         | x            |                                      | Client private key for sRPC. |
|	sinequa-ssl-client-override-host-name   | x         | x            |                                      | Overrides host name for sRPC. |

### 2.2. Leverage Storage Account <a name="storageaccount">

To reduce the cost of the disk usage and have a better reliability and availabilty on data, `Blob Storage Account` is broadly used for all data that do not require high I/O performances.

If a `sinequa-data-storage-url` `Cloud Tag` is provided, the components below will automatically switch from `DataDisk` to `Storage Account`.

It concerns:
* Document cache store
* User settings
* Registry
* **New config store**
* Audit store
* Log store

**WIP**

### 2.3. Leverage Scale Set for Elasticity <a name="scaleset">

To reduce the cost of VM usage and control the indexing workload, `Scale Set` is used to scale up & down the number of indexers based on the indexing workload.

**WIP**

### 2.4. Back Up and Restore the Application <a name="backup">

Thanks to [Storage Accounts](#storageaccount), you can easily back up and restore all stores. 

* You can back up the engine directly into `Storage Acccount`.
* You can automatically restore the engine from `Storage Acccount` if indexes disappears (due to NVMe disk Azure policy).
* ...

**WIP**
