$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
    Authorization              = "Bearer $token"
    "Content-Type"             = "application/json; charset=utf-8"
    "OData-MaxVersion"         = "4.0"
    "OData-Version"            = "4.0"
    "MSCRM.SolutionUniqueName" = "DMVDigitalServicesPortal"
    "MSCRM.MergeLabels"        = "true"
}

$entities = @(
    @{ name = "dmv_driverlicense";       svg = "dmv_/icons/license.svg";       png = "dmv_/icons/license_icon.png" }
    @{ name = "dmv_vehicle";             svg = "dmv_/icons/vehicle.svg";       png = "dmv_/icons/vehicle_icon.png" }
    @{ name = "dmv_vehicleregistration"; svg = "dmv_/icons/registration.svg";  png = "dmv_/icons/registration_icon.png" }
    @{ name = "dmv_appointment";         svg = "dmv_/icons/appointment.svg";   png = "dmv_/icons/appointment_icon.png" }
    @{ name = "dmv_documentupload";      svg = "dmv_/icons/document.svg";      png = "dmv_/icons/document_icon.png" }
    @{ name = "dmv_vehicletitle";        svg = "dmv_/icons/title.svg";         png = "dmv_/icons/title_icon.png" }
    @{ name = "dmv_lien";                svg = "dmv_/icons/lien.svg";          png = "dmv_/icons/lien_icon.png" }
    @{ name = "dmv_temporarytag";        svg = "dmv_/icons/temptag.svg";       png = "dmv_/icons/temptag_icon.png" }
    @{ name = "dmv_bulksubmission";      svg = "dmv_/icons/bulk.svg";          png = "dmv_/icons/bulk_icon.png" }
    @{ name = "dmv_transactionlog";      svg = "dmv_/icons/transaction.svg";   png = "dmv_/icons/transaction_icon.png" }
    @{ name = "dmv_notification";        svg = "dmv_/icons/notification.svg";  png = "dmv_/icons/notification_icon.png" }
    @{ name = "dmv_dmvoffice";           svg = "dmv_/icons/office.svg";        png = "dmv_/icons/office_icon.png" }
)

$ok = 0
$fail = 0

foreach ($ent in $entities) {
    $body = @{
        IconSmallName  = $ent.png
        IconMediumName = $ent.png
        IconVectorName = $ent.svg
    } | ConvertTo-Json

    try {
        Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$($ent.name)')" `
            -Method Put -Headers $h `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) `
            -UseBasicParsing | Out-Null
        Write-Host "OK: $($ent.name)"
        $ok++
    } catch {
        $msg = $_.ErrorDetails.Message
        if ($msg.Length -gt 150) { $msg = $msg.Substring(0,150) }
        Write-Host "FAIL: $($ent.name) => $msg"
        $fail++
    }
}

Write-Host "`n$ok OK, $fail failed"

# Publish all entities + app
Write-Host "`nPublishing..."
$entXml = ""
foreach ($ent in $entities) {
    $entXml += "<entity>$($ent.name)</entity>"
}

$appId = "d6331d8d-a239-f111-88b4-001dd80a6132"
$pubBody = @{
    ParameterXml = "<importexportxml><entities>$entXml</entities><appmodules><appmodule>$appId</appmodule></appmodules></importexportxml>"
} | ConvertTo-Json -Compress

try {
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/PublishXml" -Method Post -Headers $h `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($pubBody)) -UseBasicParsing | Out-Null
    Write-Host "Published"
} catch {
    Write-Host "Publish error: $($_.ErrorDetails.Message)"
}
