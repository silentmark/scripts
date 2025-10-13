az group create -n rg-dev-contoso-003 -l westeurope

az deployment group create --resource-group rg-dev-contoso-002 --template-file main.bicep --parameters adminPassword='P@ssw0rd1234!' --verbose

