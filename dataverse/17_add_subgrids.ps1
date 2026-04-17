$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$headers = @{
    Authorization    = "Bearer $token"
    "OData-MaxVersion" = "4.0"
    "OData-Version"    = "4.0"
}
$patchHeaders = @{
    Authorization      = "Bearer $token"
    "OData-MaxVersion" = "4.0"
    "OData-Version"    = "4.0"
    "Content-Type"     = "application/json"
}

# ═══════════════════════════════════════════════════════════════
# 1. Registration form → add "Term History" tab with sub-grid
# ═══════════════════════════════════════════════════════════════
$regFormId = "65dc8f05-7b9e-4e9f-a3a0-9fc0b5f7b638"
Write-Host "Fetching registration form..."
$regForm = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/systemforms($regFormId)?`$select=formxml" -Headers $headers
$regXml = $regForm.formxml

if ($regXml -match "TermsSubgrid") {
    Write-Host "  SKIP: Terms sub-grid already exists"
} else {
    $termTab = '<tab name="TERMS_TAB" id="{a2000001-0001-0001-0001-000000000001}" showlabel="true" expanded="true"><labels><label description="Term History" languagecode="1033" /></labels><columns><column width="100%"><sections><section name="TERMS_SEC" showlabel="false" showbar="false" id="{b2000001-0001-0001-0001-000000000001}" columns="1"><labels><label description="Terms" languagecode="1033" /></labels><rows><row><cell id="{c4000001-0001-0001-0001-000000000001}" showlabel="false" colspan="1" rowspan="10" auto="false"><labels><label description="Terms" languagecode="1033" /></labels><control id="TermsSubgrid" classid="{E7A81278-8635-4D9E-8D4D-59480B391C5B}" indicationOfSubgrid="true" uniqueid="{d4000001-0001-0001-0001-000000000001}"><parameters><TargetEntityType>dmv_registrationterm</TargetEntityType><ViewId>{ee5b49a3-7a75-4d77-b04c-72086709eaf1}</ViewId><IsUserView>false</IsUserView><RelationshipName>dmv_vehreg_regterm</RelationshipName><AutoExpand>Fixed</AutoExpand><EnableQuickFind>false</EnableQuickFind><EnableViewPicker>false</EnableViewPicker><EnableJumpBar>false</EnableJumpBar><ChartGridMode>Grid</ChartGridMode><VisualizationId /><IsUserChart>false</IsUserChart><EnableChartPicker>false</EnableChartPicker><RecordsPerPage>10</RecordsPerPage></parameters></control></cell></row></rows></section></sections></column></columns></tab>'

    $newRegXml = $regXml.Replace("</tabs></form>", "$termTab</tabs></form>")
    Write-Host "  New XML length: $($newRegXml.Length) (was $($regXml.Length))"

    $body = @{ formxml = $newRegXml } | ConvertTo-Json -Depth 3
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    try {
        Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/systemforms($regFormId)" -Headers $patchHeaders -Method Patch -Body $bytes
        Write-Host "  SUCCESS: Registration form updated with Terms sub-grid"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)"
        Write-Host "  DETAIL: $($_.ErrorDetails.Message)"
    }
}

# ═══════════════════════════════════════════════════════════════
# 2. Term form → add "Payment" tab with sub-grid
# ═══════════════════════════════════════════════════════════════
$termFormId = "08509d60-d139-f111-88b4-001dd80340cd"
Write-Host "`nFetching term form..."
$termForm = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/systemforms($termFormId)?`$select=formxml" -Headers $headers
$termXml = $termForm.formxml

if ($termXml -match "PaymentSubgrid") {
    Write-Host "  SKIP: Payment sub-grid already exists"
} else {
    $payTab = '<tab name="PAYMENT_TAB" id="{a3000001-0001-0001-0001-000000000001}" showlabel="true" expanded="true"><labels><label description="Payment" languagecode="1033" /></labels><columns><column width="100%"><sections><section name="PAYMENT_SEC" showlabel="false" showbar="false" id="{b3000001-0001-0001-0001-000000000001}" columns="1"><labels><label description="Payment" languagecode="1033" /></labels><rows><row><cell id="{c5000001-0001-0001-0001-000000000001}" showlabel="false" colspan="1" rowspan="6" auto="false"><labels><label description="Payment" languagecode="1033" /></labels><control id="PaymentSubgrid" classid="{E7A81278-8635-4D9E-8D4D-59480B391C5B}" indicationOfSubgrid="true" uniqueid="{d5000001-0001-0001-0001-000000000001}"><parameters><TargetEntityType>dmv_registrationpayment</TargetEntityType><ViewId>{0596f6b2-6f32-4f67-bd10-75448cc2218f}</ViewId><IsUserView>false</IsUserView><RelationshipName>dmv_regterm_regpayment</RelationshipName><AutoExpand>Fixed</AutoExpand><EnableQuickFind>false</EnableQuickFind><EnableViewPicker>false</EnableViewPicker><EnableJumpBar>false</EnableJumpBar><ChartGridMode>Grid</ChartGridMode><VisualizationId /><IsUserChart>false</IsUserChart><EnableChartPicker>false</EnableChartPicker><RecordsPerPage>5</RecordsPerPage></parameters></control></cell></row></rows></section></sections></column></columns></tab>'

    $newTermXml = $termXml.Replace("</tabs></form>", "$payTab</tabs></form>")
    Write-Host "  New XML length: $($newTermXml.Length) (was $($termXml.Length))"

    $body2 = @{ formxml = $newTermXml } | ConvertTo-Json -Depth 3
    $bytes2 = [System.Text.Encoding]::UTF8.GetBytes($body2)
    try {
        Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/systemforms($termFormId)" -Headers $patchHeaders -Method Patch -Body $bytes2
        Write-Host "  SUCCESS: Term form updated with Payment sub-grid"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)"
        Write-Host "  DETAIL: $($_.ErrorDetails.Message)"
    }
}

Write-Host "`n=== DONE ==="
