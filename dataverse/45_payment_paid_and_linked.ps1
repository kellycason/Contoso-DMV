# 45_payment_paid_and_linked.ps1
# 1) Add lookup dmv_renewalid on dmv_registrationpayment → dmv_registrationrenewal
# 2) Backfill existing Unpaid payments → Paid and link where possible

$ErrorActionPreference = "Stop"
$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
  Authorization = "Bearer $token"
  "Content-Type" = "application/json; charset=utf-8"
  "OData-MaxVersion" = "4.0"
  "OData-Version" = "4.0"
  "MSCRM.SolutionUniqueName" = "DMVDigitalServicesPortal"
}
$readH = @{ Authorization = "Bearer $token"; "OData-Version" = "4.0" }

# ─────────────────────────────────────────────────────────────────────
# 1) Create N:1 lookup dmv_renewalid on payment → renewal (if missing)
# ─────────────────────────────────────────────────────────────────────
$attrs = (Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='dmv_registrationpayment')/Attributes?`$select=LogicalName" -Headers $readH).value
$hasRenewalLookup = ($attrs | Where-Object { $_.LogicalName -eq 'dmv_renewalid' }).Count -gt 0
if ($hasRenewalLookup) {
  Write-Host "Lookup dmv_renewalid already exists on payment."
} else {
  Write-Host "Creating lookup dmv_renewalid on dmv_registrationpayment → dmv_registrationrenewal..."
  $relBody = @{
    "@odata.type" = "Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata"
    SchemaName = "dmv_dmv_registrationrenewal_dmv_registrationpayment_renewal"
    ReferencedEntity  = "dmv_registrationrenewal"
    ReferencingEntity = "dmv_registrationpayment"
    RelationshipType = "OneToManyRelationship"
    Lookup = @{
      "@odata.type" = "Microsoft.Dynamics.CRM.LookupAttributeMetadata"
      SchemaName = "dmv_RenewalId"
      DisplayName = @{ LocalizedLabels = @(@{ Label = "Renewal"; LanguageCode = 1033 }) }
      Description = @{ LocalizedLabels = @(@{ Label = "The registration renewal this payment belongs to."; LanguageCode = 1033 }) }
      RequiredLevel = @{ Value = "None" }
    }
    AssociatedMenuConfiguration = @{
      Behavior = "UseCollectionName"
      Group    = "Details"
      Order    = 10000
    }
    CascadeConfiguration = @{
      Assign="NoCascade"; Delete="RemoveLink"; Merge="NoCascade"; Reparent="NoCascade"; Share="NoCascade"; Unshare="NoCascade"
    }
  } | ConvertTo-Json -Depth 20
  Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/RelationshipDefinitions" -Method Post -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($relBody)) -UseBasicParsing | Out-Null
  Write-Host "  Created."
}

# Publish customizations so the new column is queryable
Write-Host "Publishing customizations..."
$pubBody = @{ ParameterXml = "<importexportxml><entities><entity>dmv_registrationpayment</entity></entities></importexportxml>" } | ConvertTo-Json -Compress
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/PublishXml" -Method Post -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($pubBody)) -UseBasicParsing | Out-Null

# ─────────────────────────────────────────────────────────────────────
# 2) Backfill: Flip Unpaid → Paid. Link to matching renewal by
#    dmv_paymentconfirmation == dmv_paymentref if found, else by term.
# ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Backfill Unpaid payments → Paid ==="
$unpaid = (Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_registrationpayments?`$filter=dmv_paymentstatus eq 100000000&`$select=dmv_registrationpaymentid,dmv_paymentref,dmv_amount,_dmv_registrationtermid_value" -Headers $readH).value
Write-Host "Found $($unpaid.Count) unpaid"

foreach ($p in $unpaid) {
  $updates = @{ dmv_paymentstatus = 100000001 }

  # Try to link to a renewal by matching paymentconfirmation == paymentref
  $match = (Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_registrationrenewals?`$filter=dmv_paymentconfirmation eq '$($p.dmv_paymentref)'&`$select=dmv_registrationrenewalid&`$top=1" -Headers $readH).value
  if ($match -and $match.Count -gt 0) {
    $updates["dmv_RenewalId@odata.bind"] = "/dmv_registrationrenewals($($match[0].dmv_registrationrenewalid))"
    Write-Host "  $($p.dmv_paymentref) → Paid, linked to renewal $($match[0].dmv_registrationrenewalid)"
  } else {
    # Try by term's vehicle reg → most recent renewal for that vehicle reg
    if ($p._dmv_registrationtermid_value) {
      $term = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_registrationterms($($p._dmv_registrationtermid_value))?`$select=_dmv_vehicleregistrationid_value" -Headers $readH -ErrorAction SilentlyContinue
      if ($term -and $term._dmv_vehicleregistrationid_value) {
        $r2 = (Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_registrationrenewals?`$filter=_dmv_registrationid_value eq $($term._dmv_vehicleregistrationid_value)&`$orderby=createdon desc&`$select=dmv_registrationrenewalid&`$top=1" -Headers $readH).value
        if ($r2 -and $r2.Count -gt 0) {
          $updates["dmv_RenewalId@odata.bind"] = "/dmv_registrationrenewals($($r2[0].dmv_registrationrenewalid))"
          Write-Host "  $($p.dmv_paymentref) → Paid, linked via term to renewal $($r2[0].dmv_registrationrenewalid)"
        } else {
          Write-Host "  $($p.dmv_paymentref) → Paid (no matching renewal)"
        }
      } else {
        Write-Host "  $($p.dmv_paymentref) → Paid (no term vehicle reg)"
      }
    } else {
      Write-Host "  $($p.dmv_paymentref) → Paid (no term)"
    }
  }

  $body = $updates | ConvertTo-Json
  Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_registrationpayments($($p.dmv_registrationpaymentid))" -Method Patch -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
}

Write-Host ""
Write-Host "Done."
