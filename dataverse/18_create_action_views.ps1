$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$headers = @{
    Authorization      = "Bearer $token"
    "OData-MaxVersion" = "4.0"
    "OData-Version"    = "4.0"
    "Content-Type"     = "application/json"
}

# ═══════════════════════════════════════════════════════════════
# 1. "Pending Terms – Action Required" view (dmv_registrationterm)
#    Shows only terms with status=Pending (100000001)
#    This is the employee's work queue
# ═══════════════════════════════════════════════════════════════
Write-Host "Creating 'Pending Terms - Action Required' view..."

$pendingTermsFetch = @'
<fetch version="1.0" output-format="xml-platform" mapping="logical">
  <entity name="dmv_registrationterm">
    <attribute name="dmv_termnumber" />
    <attribute name="dmv_termtype" />
    <attribute name="dmv_termstatus" />
    <attribute name="dmv_vehicleregistrationid" />
    <attribute name="dmv_startdate" />
    <attribute name="dmv_enddate" />
    <attribute name="dmv_issuedate" />
    <attribute name="dmv_registrationtermid" />
    <attribute name="createdon" />
    <filter type="and">
      <condition attribute="dmv_termstatus" operator="eq" value="100000001" />
    </filter>
    <order attribute="createdon" descending="true" />
  </entity>
</fetch>
'@

$pendingTermsLayout = @'
<grid name="dmv_registrationterms" object="11408" jump="dmv_termnumber" select="1" icon="1" preview="1">
  <row name="dmv_registrationterm" id="dmv_registrationtermid">
    <cell name="dmv_termnumber" width="150" />
    <cell name="dmv_termtype" width="100" />
    <cell name="dmv_termstatus" width="110" />
    <cell name="dmv_vehicleregistrationid" width="180" />
    <cell name="dmv_startdate" width="120" />
    <cell name="dmv_enddate" width="120" />
    <cell name="createdon" width="140" />
  </row>
</grid>
'@

# Clean up whitespace from here-strings
$pendingTermsFetch = ($pendingTermsFetch -replace "`r`n", "" -replace "`n", "" -replace ">\s+<", "><").Trim()
$pendingTermsLayout = ($pendingTermsLayout -replace "`r`n", "" -replace "`n", "" -replace ">\s+<", "><").Trim()

$pendingTermsBody = @{
    name              = "Pending Terms - Action Required"
    returnedtypecode  = "dmv_registrationterm"
    querytype         = 0
    fetchxml          = $pendingTermsFetch
    layoutxml         = $pendingTermsLayout
    description       = "Terms submitted by citizens awaiting review and payment processing. This is the employee work queue."
} | ConvertTo-Json -Depth 3

try {
    $r1 = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/savedqueries" -Headers $headers -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($pendingTermsBody))
    $pendingTermsViewId = ($r1.Headers["OData-EntityId"] -replace ".*\(","" -replace "\).*","")
    Write-Host "  OK: Created view $pendingTermsViewId"
} catch {
    Write-Host "  ERR: $($_.ErrorDetails.Message)"
}

# ═══════════════════════════════════════════════════════════════
# 2. "Unpaid Payments – Action Required" view (dmv_registrationpayment)
#    Shows only payments with status=Unpaid (100000000)
# ═══════════════════════════════════════════════════════════════
Write-Host "`nCreating 'Unpaid Payments - Action Required' view..."

$unpaidPaymentsFetch = @'
<fetch version="1.0" output-format="xml-platform" mapping="logical">
  <entity name="dmv_registrationpayment">
    <attribute name="dmv_paymentref" />
    <attribute name="dmv_paymentstatus" />
    <attribute name="dmv_amount" />
    <attribute name="dmv_latefee" />
    <attribute name="dmv_total" />
    <attribute name="dmv_paymentmethod" />
    <attribute name="dmv_paymentdate" />
    <attribute name="dmv_registrationtermid" />
    <attribute name="dmv_registrationpaymentid" />
    <attribute name="createdon" />
    <filter type="and">
      <condition attribute="dmv_paymentstatus" operator="eq" value="100000000" />
    </filter>
    <order attribute="createdon" descending="true" />
  </entity>
</fetch>
'@

$unpaidPaymentsLayout = @'
<grid name="dmv_registrationpayments" object="11409" jump="dmv_paymentref" select="1" icon="1" preview="1">
  <row name="dmv_registrationpayment" id="dmv_registrationpaymentid">
    <cell name="dmv_paymentref" width="140" />
    <cell name="dmv_paymentstatus" width="100" />
    <cell name="dmv_amount" width="90" />
    <cell name="dmv_latefee" width="90" />
    <cell name="dmv_total" width="90" />
    <cell name="dmv_registrationtermid" width="160" />
    <cell name="createdon" width="140" />
  </row>
</grid>
'@

$unpaidPaymentsFetch = ($unpaidPaymentsFetch -replace "`r`n", "" -replace "`n", "" -replace ">\s+<", "><").Trim()
$unpaidPaymentsLayout = ($unpaidPaymentsLayout -replace "`r`n", "" -replace "`n", "" -replace ">\s+<", "><").Trim()

$unpaidPaymentsBody = @{
    name              = "Unpaid Payments - Action Required"
    returnedtypecode  = "dmv_registrationpayment"
    querytype         = 0
    fetchxml          = $unpaidPaymentsFetch
    layoutxml         = $unpaidPaymentsLayout
    description       = "Payments awaiting processing. Mark as Paid once payment is received."
} | ConvertTo-Json -Depth 3

try {
    $r2 = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/savedqueries" -Headers $headers -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($unpaidPaymentsBody))
    $unpaidPaymentsViewId = ($r2.Headers["OData-EntityId"] -replace ".*\(","" -replace "\).*","")
    Write-Host "  OK: Created view $unpaidPaymentsViewId"
} catch {
    Write-Host "  ERR: $($_.ErrorDetails.Message)"
}

# ═══════════════════════════════════════════════════════════════
# 3. "Terms by Status" chart (dmv_registrationterm)
#    Pie chart grouped by dmv_termstatus — shows at-a-glance workload
# ═══════════════════════════════════════════════════════════════
Write-Host "`nCreating 'Terms by Status' chart..."

$chartDataXml = @'
<datadefinition>
  <fetchcollection>
    <fetch mapping="logical" aggregate="true">
      <entity name="dmv_registrationterm">
        <attribute name="dmv_registrationtermid" aggregate="count" alias="count" />
        <attribute name="dmv_termstatus" groupby="true" alias="status" />
      </entity>
    </fetch>
  </fetchcollection>
  <categorycollection>
    <category>
      <measurecollection>
        <measure alias="count" />
      </measurecollection>
    </category>
  </categorycollection>
</datadefinition>
'@

$chartPresentationXml = @'
<Chart Palette="None" PaletteCustomColors="91,154,213; 237,125,49; 165,165,165">
  <Series>
    <Series Name="count" IsValueShownAsLabel="True" ChartType="Pie" Font="{0}, 9.5px" LabelForeColor="59, 59, 59" CustomProperties="PieLabelStyle=Outside, PieDrawingStyle=Default" />
  </Series>
  <ChartAreas>
    <ChartArea Name="ChartArea1">
      <Area3DStyle Enable3D="False" />
    </ChartArea>
  </ChartAreas>
  <Legends>
    <Legend Name="Legend1" Alignment="Center" Docking="Bottom" Font="{0}, 11px" ForeColor="59, 59, 59" />
  </Legends>
</Chart>
'@

$chartDataXml = ($chartDataXml -replace "`r`n", "" -replace "`n", "" -replace ">\s+<", "><").Trim()
$chartPresentationXml = ($chartPresentationXml -replace "`r`n", "" -replace "`n", "" -replace ">\s+<", "><").Trim()

$chartBody = @{
    name                   = "Terms by Status"
    primaryentitytypecode  = "dmv_registrationterm"
    datadescription        = $chartDataXml
    presentationdescription = $chartPresentationXml
    isdefault              = $false
    description            = "Pie chart showing registration terms grouped by status (Active, Pending, Expired)"
} | ConvertTo-Json -Depth 3

try {
    $r3 = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/savedqueryvisualizations" -Headers $headers -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($chartBody))
    $chartId = ($r3.Headers["OData-EntityId"] -replace ".*\(","" -replace "\).*","")
    Write-Host "  OK: Created chart $chartId"
} catch {
    Write-Host "  ERR: $($_.ErrorDetails.Message)"
}

# ═══════════════════════════════════════════════════════════════
# 4. "Payments by Status" chart (dmv_registrationpayment)
# ═══════════════════════════════════════════════════════════════
Write-Host "`nCreating 'Payments by Status' chart..."

$payChartDataXml = @'
<datadefinition>
  <fetchcollection>
    <fetch mapping="logical" aggregate="true">
      <entity name="dmv_registrationpayment">
        <attribute name="dmv_registrationpaymentid" aggregate="count" alias="count" />
        <attribute name="dmv_paymentstatus" groupby="true" alias="status" />
      </entity>
    </fetch>
  </fetchcollection>
  <categorycollection>
    <category>
      <measurecollection>
        <measure alias="count" />
      </measurecollection>
    </category>
  </categorycollection>
</datadefinition>
'@

$payChartPresXml = @'
<Chart Palette="None" PaletteCustomColors="237,125,49; 91,154,213; 165,165,165; 112,173,71">
  <Series>
    <Series Name="count" IsValueShownAsLabel="True" ChartType="Pie" Font="{0}, 9.5px" LabelForeColor="59, 59, 59" CustomProperties="PieLabelStyle=Outside, PieDrawingStyle=Default" />
  </Series>
  <ChartAreas>
    <ChartArea Name="ChartArea1">
      <Area3DStyle Enable3D="False" />
    </ChartArea>
  </ChartAreas>
  <Legends>
    <Legend Name="Legend1" Alignment="Center" Docking="Bottom" Font="{0}, 11px" ForeColor="59, 59, 59" />
  </Legends>
</Chart>
'@

$payChartDataXml = ($payChartDataXml -replace "`r`n", "" -replace "`n", "" -replace ">\s+<", "><").Trim()
$payChartPresXml = ($payChartPresXml -replace "`r`n", "" -replace "`n", "" -replace ">\s+<", "><").Trim()

$payChartBody = @{
    name                   = "Payments by Status"
    primaryentitytypecode  = "dmv_registrationpayment"
    datadescription        = $payChartDataXml
    presentationdescription = $payChartPresXml
    isdefault              = $false
    description            = "Pie chart showing payments grouped by status (Unpaid, Paid, Refunded, Waived)"
} | ConvertTo-Json -Depth 3

try {
    $r4 = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/savedqueryvisualizations" -Headers $headers -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($payChartBody))
    $payChartId = ($r4.Headers["OData-EntityId"] -replace ".*\(","" -replace "\).*","")
    Write-Host "  OK: Created chart $payChartId"
} catch {
    Write-Host "  ERR: $($_.ErrorDetails.Message)"
}

# ═══════════════════════════════════════════════════════════════
# 5. Publish
# ═══════════════════════════════════════════════════════════════
Write-Host "`nPublishing customizations..."
$pubBody = '{"ParameterXml":"<importexportxml><entities><entity>dmv_registrationterm</entity><entity>dmv_registrationpayment</entity></entities></importexportxml>"}'
try {
    Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/PublishXml" -Headers $headers -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($pubBody))
    Write-Host "  OK: Published"
} catch {
    Write-Host "  ERR: $($_.ErrorDetails.Message)"
}

Write-Host "`n=== SUMMARY ==="
Write-Host "Pending Terms view:    $pendingTermsViewId"
Write-Host "Unpaid Payments view:  $unpaidPaymentsViewId"
Write-Host "Terms by Status chart: $chartId"
Write-Host "Payments by Status chart: $payChartId"
Write-Host "=== DONE ==="
