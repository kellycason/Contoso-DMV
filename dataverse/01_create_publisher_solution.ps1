$ErrorActionPreference = "Stop"
$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json; charset=utf-8"; "OData-MaxVersion" = "4.0"; "OData-Version" = "4.0" }

# --- STEP 1: Create Publisher ---
$pubCheck = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/publishers?`$filter=uniquename eq 'dmv'&`$select=publisherid,customizationprefix" -Method Get -Headers $h
if ($pubCheck.value.Count -gt 0) {
    $pubId = $pubCheck.value[0].publisherid
    Write-Host "Publisher already exists: $pubId"
} else {
    $pubBody = @{
        friendlyname = "DMV"
        uniquename = "dmv"
        customizationprefix = "dmv"
        customizationoptionvalueprefix = 10000
        description = "Custom publisher for DMV Digital Services Portal"
    } | ConvertTo-Json
    $pubResp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/publishers" -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($pubBody)) -UseBasicParsing
    $pubId = ($pubResp.Headers["OData-EntityId"] -replace '.*\(','') -replace '\)',''
    Write-Host "Publisher created: $pubId"
}

# --- STEP 2: Create Solution ---
$solCheck = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/solutions?`$filter=uniquename eq 'DMVDigitalServicesPortal'&`$select=solutionid" -Method Get -Headers $h
if ($solCheck.value.Count -gt 0) {
    $solId = $solCheck.value[0].solutionid
    Write-Host "Solution already exists: $solId"
} else {
    $solBody = @{
        friendlyname = "DMV Digital Services Portal"
        uniquename = "DMVDigitalServicesPortal"
        version = "1.0.0.0"
        "publisherid@odata.bind" = "/publishers($pubId)"
        description = "All Dataverse tables, relationships, and customizations for the DMV demo portal."
    } | ConvertTo-Json
    $solResp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/solutions" -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($solBody)) -UseBasicParsing
    $solId = ($solResp.Headers["OData-EntityId"] -replace '.*\(','') -replace '\)',''
    Write-Host "Solution created: $solId"
}

Write-Host "Publisher ID: $pubId"
Write-Host "Solution ID: $solId"
