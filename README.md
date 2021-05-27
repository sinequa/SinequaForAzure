# Sinequa For Azure (S4A)

Sinequa For Azure (S4A) is a set of Capabilities and Dedicated Features designed for Azure.

#### Table of contents
1. [Content of this repository](#content)<br>
2. [Sinequa Azure Features](#features)<br>
2.1. [Cloud Init](#cloudinit)<br>
2.2. [Leverage Strorage Account](#storageaccount)<br>
2.3. [Leverage Scale Set for Elasticity](#scaleset)<br>
2.4. [Application Backup & Restore](#backup)<br>
  
## 1. Content of this repository <a name="content">

This repository contains:
* **[Powershell](./S4A_Image)** scripts for building your **own Sinequa Image**
* **[ARM](./ARM)** templates sample for **deploying a Sinequa Grid**
* **[Terraform](./Terraform)** samples for **deploying a Sinequa Grid**

![Sinequa For Azure](images/S4A.png)


## 2. Sinequa Azure Features <a name="features">

### 2.1. Cloud Init <a name="cloudinit">

`Cloud Init` features are some capabilities during a VM deployement for initalizing a Sinequa Node for having a Ready-To-Go Node which is automaticaly registered into a Grid and whith some roles enabled (like engine, indexer, ...).


#### 2.1.1. Environment Variable <a name="envvars">

The **SINEQUA_CLOUD** `Environment Variable` has to be set before starting the Sinequa service for enabling **Cloud Init** Features

| Name                     | Value                                | Description                          |
| ------------------------ | ------------------------------------ | ------------------------------------ |
|	SINEQUA_CLOUD            | "Azure"                              | Enable Cloud Init features           |


#### 2.1.2. Cloud Tags <a name="cloudtags">

`Cloud Tags` are Azure Tags used on Azure resources. They are used for executing some specific init taks for a particular VM or VMSS. 

| Name                     | Value Example                        | Description                          |
| ------------------------ | ------------------------------------ | ------------------------------------ |
|	sinequa-data-storage-url | https://`{storage account name}`.blob.core.windows.net/`{container}` | Used for enabling storage of<br>* Configuration<br>* User Settings<br>* Document Cache<br>* Log Store<br>* Audit Store<br>and for declaring `Cloud Vars` <br>(see bellow)|
| sinequa-auto-disk         | "auto" or JSON value                | When adding datadisk to an Azure VM there are not partitioned/formated. By using "auto", all raw disks will be automaticaly enebled |
|	sinequa-path		          | "f:\sinequa".  Default is `distrib_path` | `sinequa-path` is the root folder for all customer data, in oppositon of `distrib-path` that contains only binaries on the OS disk. `sinequa-path` should be located on a dedicated Azure DataDisk |
|	sinequa-index-path	      | "g:\sinequa". Optional. Default is sinequa-path | `sinequa-index-path` is the root folder for all indexes. It's recommend to use it for NVMe disks | 
|	sinequa-node              | "node1"                             | Node name |
| sinequa-primary-node-id   | 1 (or 2 or 3 or empty)              | To be used on primary nodes |
|	sinequa-webapp 		        | "webapp1"                           | Name of the webapp to create and start on this node |
|	sinequa-engine		        | "engine1"                           | Name of the engine to create and start on this node |
|	sinequa-indexer		        | "indexer1"                          | Name of the indexer to create and start on this node |


#### 2.1.3. Cloud Vars & Cloud Secrets <a name="cloudvars">

* `Cloud Vars` are `Azure blobs` stored in the `Storage Account`. They are used for declaring global variables in the configuration.
* `Cloud Secrets` are `secrets` stored in the `Key Vault` defined in `Cloud Vars`. They are used for storing sensitive data.

| Name                                    | Cloud Var | Cloud Secret | Value Example                        | Description                          |
| --------------------------------------- | --------- | ------------ | ------------------------------------ | ------------------------------------ |
|	sinequa-primary-nodes                   | x         |              | "1=srpc://vm-node1:10300;2=srpc://vm-node2:10300;3=srpc://vm-node3=10300" | sRPC Connection string of primary nodes |
| sinequa-keyvault 	                      | x         |              | "kv-grid1"                           | Name of the Key Vault containing secrets (see bellow) |
| sinequa-queue-cluster 	                | x         |              | "QueueCluster1(vm-node1,vm-node2,vm-node3)" | Create and start a QueueCluster |
| sinequa-encryption-key                  | x         | x            | xxxxx                                | Encryption key (see https://doc.sinequa.com/en.sinequa-es.v11/Content/en.sinequa-es.how-to.encrypt.html#generating-encryption-key) |
|	sinequa-license		                      | x         | x            | xxxxx                                | Sinequa License |
|	sinequa-ssl-force                       | x         | x            | true or false                        | Force SSL on sRPC |
|	sinequa-ssl-roots-pem-file              | x         | x            |                                      | pem file for sRPC |
|	sinequa-ssl-server-ca-crt               | x         | x            |                                      | ca crt file for sRPC |
|	sinequa-ssl-server-crt                  | x         | x            |                                      | server crt file for sRPC |
|	sinequa-ssl-server-key                  | x         | x            |                                      | server private key for sRPC |
|	sinequa-ssl-client-certificate-check    | x         | x            |                                      | client certificate check for sRPC |
|	sinequa-ssl-client-ca-crt               | x         | x            |                                      | client ca crt file for sRPC |
|	sinequa-ssl-client-crt                  | x         | x            |                                      | client crt file for sRPC |
|	sinequa-ssl-client-key                  | x         | x            |                                      | client private key for sRPC |
|	sinequa-ssl-client-override-host-name   | x         | x            |                                      | override host name for sRPC |

### 2.2. Leverage Strorage Account <a name="storageaccount">

In order to reduce the cost of the disk usage and to have a better reliability and availibilty on data, `Blob Storage Account` is broadly used for all data that not require high I/O performances.

If a `sinequa-data-storage-url` `Cloud Tag` is provided, the components bellows will automaticaly switch from `DataDisk` to `Storage Account`.

It concerns:
* Document Cache Store
* User Settings
* Registry
* **New Config Store**
* Audit Store
* Log Store

**WIP**

### 2.3. Leverage Scale Set for Elasticity <a name="scaleset">

In order to reduce the cost of VM usage and to control the indexing workload, `Scale Set` is used for scaling-up & scaling-down the number of Indexers depending on the indexing workload

**WIP**

### 2.4. Application Backup & Restore <a name="backup">

Thanks to [Storage Accounts](#storageaccount), all store can be easily backuped and restored. 

* Engine can backup directly into `Storage Acccount`
* Engine can restore automatilacy from `Storage Acccount` if indexes disapeared (due to NVMe disk Azure policy)
* ...

**WIP**
