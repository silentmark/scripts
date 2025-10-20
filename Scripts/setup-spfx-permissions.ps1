
connect-MgGraph -scopes "Application.ReadWrite.All", "Directory.ReadWrite.All" -NoWelcome

$appID =       "e873c0d0-5003-4741-b57a-97d10147c912" # To należy zmienić na ID aplikacji, do której chcemy nadać uprawnienia
$sPFxAppID =   "08e18876-6177-487e-b8b5-cf950c1e598c" # To pozostaje bez zmian - to jest ID aplikacji Microsoft SharePoint Client Extensibility

    $sPFxSP =  Get-MgServicePrincipal -Filter "appid eq '$spfxAppID'" -ErrorAction Stop
    $resourceSP =  Get-MgServicePrincipal -Filter "appid eq '$appID'" -ErrorAction Stop
    $params = @{
        "clientId" = $sPFxSP.id
        "ConsentType" = "AllPrincipals"
        "ResourceId" = $resourceSP.id
        "scope" = $scope
        }
New-MgOauth2PermissionGrant -BodyParameter $params -ErrorAction Stop