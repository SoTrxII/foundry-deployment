# Foundry TTS on Azure

This sample shows how to deploys [Foundry VTT](https://foundryvtt.com/) on Microsoft Azure in a cost efficient manner.

The main branch uses [Azure Container Apps](https://azure.microsoft.com/fr-fr/products/container-apps/) to deploy Foundry VTT in a serverless manner. Another branch, `app-services`, uses [Azure App Services](https://azure.microsoft.com/fr-fr/products/app-service/) instead, but isn't serverless. 


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
