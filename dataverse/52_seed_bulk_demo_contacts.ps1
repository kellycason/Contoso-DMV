# 52_seed_bulk_demo_contacts.ps1
# Creates the 5 demo citizen contacts used by the Bulk Registration CSV template.
# Safe to run multiple times — skips existing emails.

$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
  Authorization = "Bearer $token"
  "OData-MaxVersion" = "4.0"
  "OData-Version" = "4.0"
  "Content-Type" = "application/json"
  Accept = "application/json"
}

$contacts = @(
  @{ first="Alice";  last="Nguyen";  email="alice.nguyen@example.com";  phone="(555) 201-4411"; addr="842 Oak St";       city="Contoso"; state="TX"; zip="78704" }
  @{ first="Brian";  last="Patel";   email="brian.patel@example.com";   phone="(555) 201-4412"; addr="112 Elm Ave";      city="Contoso"; state="TX"; zip="78704" }
  @{ first="Carmen"; last="Ortiz";   email="carmen.ortiz@example.com";  phone="(555) 201-4413"; addr="2203 Pinewood Dr"; city="Contoso"; state="TX"; zip="78704" }
  @{ first="Derek";  last="Johnson"; email="derek.johnson@example.com"; phone="(555) 201-4414"; addr="55 Maple Ct";      city="Contoso"; state="TX"; zip="78704" }
  @{ first="Eliana"; last="Rivera";  email="eliana.rivera@example.com"; phone="(555) 201-4415"; addr="913 Cedar Ln";     city="Contoso"; state="TX"; zip="78704" }
)

foreach ($c in $contacts) {
  # Check for existing
  $escaped = $c.email -replace "'", "''"
  $existing = Invoke-RestMethod -Headers $h -Uri "$envUrl/api/data/v9.2/contacts?`$filter=emailaddress1 eq '$escaped'&`$select=contactid&`$top=1"
  if ($existing.value.Count -gt 0) {
    Write-Host "  skip  $($c.first) $($c.last) — exists ($($existing.value[0].contactid))" -ForegroundColor DarkGray
    continue
  }

  $body = @{
    firstname = $c.first
    lastname = $c.last
    emailaddress1 = $c.email
    telephone1 = $c.phone
    address1_line1 = $c.addr
    address1_city = $c.city
    address1_stateorprovince = $c.state
    address1_postalcode = $c.zip
  } | ConvertTo-Json
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)

  try {
    $r = Invoke-WebRequest -Headers $h -Method Post -Uri "$envUrl/api/data/v9.2/contacts" -Body $bytes -UseBasicParsing
    $id = ($r.Headers["OData-EntityId"] -match '\(([^)]+)\)') | Out-Null; $id = $Matches[1]
    Write-Host "  ✓ created $($c.first) $($c.last) — $id" -ForegroundColor Green
  } catch {
    Write-Host "  ✗ failed  $($c.first) $($c.last): $($_.Exception.Message)" -ForegroundColor Red
  }
}

Write-Host ""
Write-Host "Done. The 5 demo contacts are now available for bulk CSV submit." -ForegroundColor Cyan
