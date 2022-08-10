# How

Create "creds.tfvars" file with 
```env
foundry_username = 
foundry_password = 
foundry_hostname = 
```

Then exec :

```sh
terraform apply -var-file="creds.tfvars"
```