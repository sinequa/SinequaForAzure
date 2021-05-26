# Sinequa For Azure (S4A)

Sinequa For Azure (S4A) is a set of Capabilities and Dedicated Features designed for Azure.

#### Table of contents
0. [Pre-requisite](#prerequisite)<br>
1. [Terraform Modules](#modules)<br>
2. [complete_grid Sample](#complete_grid)<br>
2.1. [Nodes specialization](#specify)<br>
2.2. [Add nodes to a Sinequa Grid](#add)<br>
2.2.1.  [Add a VM Node](#add_vm)<br>
2.2.2.  [Add a VMSS Node](#add_vmss)<br>
2.2.3.  [Update a Sinequa Grid](#update)<br>

  
## 1. Content of this repository

This repository contains:
* **Powershell** scripts for building your **own Sinequa Image**
* **ARM** templates sample for **deploying a Sinequa Grid**
* **Terraform** samples for **deploying a Sinequa Grid**



## 2. Sinequa Azure Features

### 2.1. Cloud Init

`Cloud Init` features are some capabilities during a VM deployement for initalizing a Sinequa Node for having a Ready-To-Go Node which is automaticaly registered into a Grid and whith some roles enabled (like engine, indexer, ...).


#### 2.2.1. Environment Variable

The **SINEQUA_CLOUD** `Environment Variable` has to be set before starting the Sinequa service for enabling **Cloud Init** Features

| Name                     | Value                                | Description                          |
| ------------------------ | ------------------------------------ | ------------------------------------ |
|	SINEQUA_CLOUD            | "Azure"                              | Enable Cloud Init features           |


#### 2.2.2. Cloud Tags

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


#### 2.2.3. Cloud Vars & Cloud Secrets

* `Cloud Vars` are Azure blobs stored in the Storage Account. They are used for declaring global variables in the configuration.
* `Cloud Secrets` are secrets stored in the Key Vault defined in Cloud Vars. They are used for storing sensitive data.

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

