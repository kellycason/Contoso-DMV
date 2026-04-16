$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
    Authorization  = "Bearer $token"
    "Content-Type" = "application/json; charset=utf-8"
    "OData-MaxVersion" = "4.0"
    "OData-Version" = "4.0"
}

$smId = "98db46b0-896f-412f-a212-01d534198efb"

$sitemapXml = '<SiteMap IntroducedVersion="7.0.0.0">' +
  '<Area Id="DMVArea" Title="DMV Operations" ShowGroups="true">' +
    '<Group Id="CitizenGroup" Title="Citizen Services">' +
      '<SubArea Id="nav_contact" Entity="contact" Title="Citizens (Contacts)" Icon="$webresource:dmv_/icons/citizen_icon.png" />' +
      '<SubArea Id="nav_driverlicense" Entity="dmv_driverlicense" Title="Driver Licenses" Icon="$webresource:dmv_/icons/license_icon.png" />' +
      '<SubArea Id="nav_appointment" Entity="dmv_appointment" Title="Appointments" Icon="$webresource:dmv_/icons/appointment_icon.png" />' +
      '<SubArea Id="nav_documentupload" Entity="dmv_documentupload" Title="Document Uploads" Icon="$webresource:dmv_/icons/document_icon.png" />' +
      '<SubArea Id="nav_notification" Entity="dmv_notification" Title="Notifications" Icon="$webresource:dmv_/icons/notification_icon.png" />' +
    '</Group>' +
    '<Group Id="VehicleGroup" Title="Vehicle Services">' +
      '<SubArea Id="nav_vehicle" Entity="dmv_vehicle" Title="Vehicles" Icon="$webresource:dmv_/icons/vehicle_icon.png" />' +
      '<SubArea Id="nav_vehiclereg" Entity="dmv_vehicleregistration" Title="Registrations" Icon="$webresource:dmv_/icons/registration_icon.png" />' +
      '<SubArea Id="nav_vehicletitle" Entity="dmv_vehicletitle" Title="Vehicle Titles" Icon="$webresource:dmv_/icons/title_icon.png" />' +
      '<SubArea Id="nav_lien" Entity="dmv_lien" Title="Liens" Icon="$webresource:dmv_/icons/lien_icon.png" />' +
    '</Group>' +
    '<Group Id="DealerGroup" Title="Dealer Operations">' +
      '<SubArea Id="nav_account" Entity="account" Title="Dealers (Accounts)" Icon="$webresource:dmv_/icons/dealer_icon.png" />' +
      '<SubArea Id="nav_temporarytag" Entity="dmv_temporarytag" Title="Temporary Tags" Icon="$webresource:dmv_/icons/temptag_icon.png" />' +
      '<SubArea Id="nav_bulksubmission" Entity="dmv_bulksubmission" Title="Bulk Submissions" Icon="$webresource:dmv_/icons/bulk_icon.png" />' +
    '</Group>' +
    '<Group Id="AdminGroup" Title="Administration">' +
      '<SubArea Id="nav_dmvoffice" Entity="dmv_dmvoffice" Title="DMV Offices" Icon="$webresource:dmv_/icons/office_icon.png" />' +
      '<SubArea Id="nav_transactionlog" Entity="dmv_transactionlog" Title="Transaction Log" Icon="$webresource:dmv_/icons/transaction_icon.png" />' +
    '</Group>' +
  '</Area>' +
'</SiteMap>'

# Update sitemap
$smBody = @{ sitemapxml = $sitemapXml } | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/sitemaps($smId)" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($smBody)) -UseBasicParsing | Out-Null
Write-Host "Sitemap updated to PNG icons"

# Publish PNG web resources
$wr = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/webresourceset?`$filter=startswith(name,'dmv_/icons/') and endswith(name,'.png')&`$select=webresourceid,name" -Headers $h
$wrIds = ""
foreach ($w in $wr.value) {
    $wrIds += "<webresource>{$($w.webresourceid)}</webresource>"
    Write-Host "  WR: $($w.name) => $($w.webresourceid)"
}

$appId = "d6331d8d-a239-f111-88b4-001dd80a6132"
$pubBody = @{
    ParameterXml = "<importexportxml><webresources>$wrIds</webresources><appmodules><appmodule>$appId</appmodule></appmodules><sitemaps><sitemap>{$smId}</sitemap></sitemaps></importexportxml>"
} | ConvertTo-Json -Compress

Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/PublishXml" -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($pubBody)) -UseBasicParsing | Out-Null
Write-Host "Published"
