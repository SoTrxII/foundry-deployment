# Foundrt TTS Azure deployment

This code deploys Foundry VTT on Azure using Terraform.

## Content 

This deployment will deploy the following resources:
- The Foundry docker image will be deployed Azure Container Apps (default : 4 vcpu/8 Gio)
- An Azure File Share to store the Foundry data
- The Log Analytics workspace to store the logs

## Deploy

You must have an active Azure Subscription. 
Create "creds.tfvars" file with

```env
# Foundry VTT account url, this is 
foundry_username =
foundry_password =
foundry_hostname =
foundry_admin_password =
```

Then exec :
```sh
terraform apply -var-file="creds.tfvars"
```

## Hotfix mount options

At this time, it seems that Terraform doesn't support the mount options for an Azure File share mounted on an Azure Container App.
To fix this, you can manually add the following mount options to the `foundry` container app in the Azure Portal:

Go to the Azure Portal, then to the `foundry` container app, then to the `Application` section in the sidebar, in the `Volumes` category.
Click on the `data` volume, then on the `Mount options` textbox add the following options:

    dir_mode=0777,file_mode=0777,uid=421,gid=421,mfsymlinks

Then click on the `Save` button.


![Mount options](./resources/hotfix-mount.png)

## Configuration

The following variables can be set in the `creds.tfvars` file:

| Variable | Description | Default |
| --- | --- | --- |
| foundry_username | The username to access the Foundry VTT account | |
| foundry_password | The password to access the Foundry VTT account | |
| foundry_hostname | The hostname of the Foundry VTT account | |
| foundry_tag | The tag to use for the Foundry VTT image | release |
| foundry_admin_password | The password to access the Foundry VTT admin | |
| base_name | The base name to name all resources | foundryvtt-prod |
| location | The Azure region to put the resources into | France Central |
| min_replicas | The minimum number of replicas for the Foundry VTT app | 0 |
| max_replicas | The maximum number of replicas for the Foundry VTT app | 1 |
| cpu_per_replica | The number of vCPUs for each replica of the Foundry VTT app | 4 |
| ram_per_replica | The amount of RAM in GiB for each replica of the Foundry VTT app | 8Gi |


