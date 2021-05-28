# Sinequa For Azure (S4A)

Sinequa For Azure (S4A) is a set of capabilities and dedicated features designed for Azure.

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

The cloud init features are some capabilities used upon VM deployment to initialize an out-of-the-box Sinequa node that is automaticaly registered into a grid with some roles enabled (like engine, indexer, etc.).


#### 2.1.1. Environment Variable <a name="envvars">

You must set the **SINEQUA_CLOUD** environment variable before starting the Sinequa service to enable **cloud init** features.

| Name                     | Value                                | Description                          |
| ------------------------ | ------------------------------------ | ------------------------------------ |
|	SINEQUA_CLOUD            | "Azure"                              | Enable cloud init features.          |


#### 2.1.2. Cloud Tags <a name="cloudtags">

Cloud tags are Azure tags used on Azure resources. They are used to run some specific init tasks for a particular VM or VMSS. 

| Name                     | Value Example                        | Description                          |
| ------------------------ | ------------------------------------ | ------------------------------------ |
|	sinequa-data-storage-url | https://`{storage account name}`.blob.core.windows.net/`{container}` | Used to enable storage of:<br>* Configuration<br>* User settings<br>* Document cache<br>* Log store<br>* Audit store<br>and to declare cloud variables <br>(see bellow).|
| sinequa-auto-disk         | "auto" or JSON value                | When adding data disks to an Azure VM, they are not partitioned/formatted. If you select "auto", all raw disks are automaticaly enabled. |
|	sinequa-path		          | "f:\sinequa".  Default is `distrib_path` | `sinequa-path` is the root folder for all customer data, as opposed to `distrib-path` that only contains binaries on the OS disk. `sinequa-path` should be located on a dedicated Azure data disk. |
|	sinequa-index-path	      | "g:\sinequa". Optional. Default is sinequa-path | `sinequa-index-path` is the root folder for all indexes. It is recommended to use it for NVMe disks. | 
|	sinequa-node              | "node1"                             | Node name. |
| sinequa-primary-node-id   | 1 (or 2 or 3 or empty)              | To be used on [primary nodes](https://doc.sinequa.com/en.sinequa-es.v11/Content/en.sinequa-es.admin-grid-primary-nodes.html). |
|	sinequa-webapp 		        | "webapp1"                           | Name of the [WebApp](https://doc.sinequa.com/en.sinequa-es.v11/Content/en.sinequa-es.admin-grid-webapps.html) to be created and started on this node.  |
|	sinequa-engine		        | "engine1"                           | Name of the [engine](https://doc.sinequa.com/en.sinequa-es.v11/Content/en.sinequa-es.admin-grid-engines.html) to be created and started on this node.  |
|	sinequa-indexer		        | "indexer1"                          | Name of the [indexer](https://doc.sinequa.com/en.sinequa-es.v11/Content/en.sinequa-es.admin-grid-indexers.html) to be created and started on this node. |


#### 2.1.3. Cloud Variables & Cloud Secrets <a name="cloudvars">

* Cloud variables are Azure blobs stored in the storage account. They are used to declare global variables in the configuration.
* Cloud secrets are secrets stored in the key vault defined in cloud variables. They are used to store sensitive data.

| Name                                    | Cloud Var | Cloud Secret | Value Example                        | Description                          |
| --------------------------------------- | --------- | ------------ | ------------------------------------ | ------------------------------------ |
|	sinequa-primary-nodes                   | x         |              | "1=srpc://vm-node1:10300;2=srpc://vm-node2:10300;3=srpc://vm-node3=10300" | sRPC connection string of primary nodes. |
| sinequa-keyvault 	                      | x         |              | "kv-grid1"                           | Name of the key vault containing secrets (see below). |
| sinequa-queue-cluster 	                | x         |              | "QueueCluster1(vm-node1,vm-node2,vm-node3)" | Creates and starts a [queue cluster](https://doc.sinequa.com/en.sinequa-es.v11/Content/en.sinequa-es.admin-grid-queue-clusters.html). |
| sinequa-encryption-key                  | x         | x            | xxxxx                                | Encryption key (see the documentation on [how to generate your own encryption key](https://doc.sinequa.com/en.sinequa-es.v11/Content/en.sinequa-es.how-to.encrypt.html#generating-encryption-key)) |
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

To reduce the cost of the disk usage and have a better reliability and availabilty on data, an Azure Blob storage account is broadly used for all data that do not require high I/O performances.

If a `sinequa-data-storage-url` cloud tag is provided, the components below will automatically switch from data disk to Azure Storage account.

It concerns:
* Document cache store
* User settings
* Registry
* **New config store**
* Audit store
* Log store

**WIP**

### 2.3. Leverage Scale Set for Elasticity <a name="scaleset">

To reduce the cost of VM usage and control the indexing workload, scale set is used to scale up & down the number of indexers based on the indexing workload.

**WIP**

### 2.4. Back Up and Restore the Application <a name="backup">

Thanks to [Storage Accounts](#storageaccount), you can easily back up and restore all stores. 

* You can back up the engine directly into an Azure Storage acccount.
* You can automatically restore the engine from Azure Storage account if indexes disappears (due to NVMe disk Azure policy).
* ...

**WIP**
