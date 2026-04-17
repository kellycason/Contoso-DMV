# 19_deploy_dashboard.ps1
# Uploads the Registration Operations Dashboard as a web resource,
# creates a dashboard icon, adds a Dashboards group to the sitemap,
# and publishes everything.

$envUrl       = "https://orga381269e.crm9.dynamics.com"
$solutionName = "DMVDigitalServicesPortal"
$appId        = "d6331d8d-a239-f111-88b4-001dd80a6132"
$smId         = "98db46b0-896f-412f-a212-01d534198efb"

# ── Auth ──
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
    Authorization    = "Bearer $token"
    "OData-MaxVersion" = "4.0"
    "OData-Version"    = "4.0"
    "Content-Type"     = "application/json"
}

# ── Step 1: Upload Dashboard HTML Web Resource ──
Write-Host "`n=== Step 1: Upload Dashboard HTML ==="
$htmlPath = Join-Path $PSScriptRoot "..\webresources\dashboard\registration_dashboard.html"
$htmlContent = [System.IO.File]::ReadAllBytes($htmlPath)
$htmlB64 = [Convert]::ToBase64String($htmlContent)
$wrName = "dmv_/dashboard/registration_dashboard.html"

# Check if exists
$existing = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/webresourceset?`$filter=name eq '$wrName'&`$select=webresourceid" -Headers $h
if ($existing.value.Count -gt 0) {
    $wrId = $existing.value[0].webresourceid
    Write-Host "  Updating existing: $wrId"
    $body = @{ content = $htmlB64 } | ConvertTo-Json
    Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/webresourceset($wrId)" -Headers $h -Method Patch `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($body))
} else {
    Write-Host "  Creating new..."
    $body = @{
        name            = $wrName
        displayname     = "Registration Operations Dashboard"
        webresourcetype = 1  # HTML
        content         = $htmlB64
    } | ConvertTo-Json
    Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/webresourceset" -Headers $h -Method Post `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
    $existing = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/webresourceset?`$filter=name eq '$wrName'&`$select=webresourceid" -Headers $h
    $wrId = $existing.value[0].webresourceid
    Write-Host "  Created: $wrId"
}

# Add to solution
try {
    $solBody = @{ ComponentId = $wrId; ComponentType = 61; SolutionUniqueName = $solutionName; AddRequiredComponents = $false } | ConvertTo-Json
    Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/AddSolutionComponent" -Headers $h -Method Post `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($solBody)) | Out-Null
    Write-Host "  Added to solution"
} catch { Write-Host "  (already in solution)" }

# ── Step 2: Create Dashboard Icon ──
Write-Host "`n=== Step 2: Create Dashboard Icon ==="

# Dashboard SVG icon (grid/chart icon)
$dashSvg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><rect x="1" y="1" width="6" height="6" rx=".5" fill="none" stroke="#333" stroke-width="1.2"/><rect x="9" y="1" width="6" height="3.5" rx=".5" fill="none" stroke="#333" stroke-width="1.2"/><rect x="1" y="9" width="6" height="6" rx=".5" fill="none" stroke="#333" stroke-width="1.2"/><rect x="9" y="6.5" width="6" height="8.5" rx=".5" fill="none" stroke="#333" stroke-width="1.2"/></svg>'
$svgB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($dashSvg))

foreach ($icon in @(
    @{ name = "dmv_/icons/dashboard.svg"; type = 11; content = $svgB64 }
)) {
    $ex = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/webresourceset?`$filter=name eq '$($icon.name)'&`$select=webresourceid" -Headers $h
    if ($ex.value.Count -gt 0) {
        Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/webresourceset($($ex.value[0].webresourceid))" -Headers $h -Method Patch `
            -Body ([System.Text.Encoding]::UTF8.GetBytes((@{ content = $icon.content } | ConvertTo-Json)))
        Write-Host "  Updated: $($icon.name)"
    } else {
        $body = @{ name = $icon.name; displayname = "dashboard icon"; webresourcetype = $icon.type; content = $icon.content } | ConvertTo-Json
        Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/webresourceset" -Headers $h -Method Post `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
        Write-Host "  Created: $($icon.name)"
    }
}

# Create PNG icon via System.Drawing
Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap(32,32)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)
$pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,51,51,51), 1.8)
# Draw grid layout
$g.DrawRectangle($pen, 2, 2, 12, 12)
$g.DrawRectangle($pen, 18, 2, 12, 7)
$g.DrawRectangle($pen, 2, 18, 12, 12)
$g.DrawRectangle($pen, 18, 13, 12, 17)
$g.Dispose(); $pen.Dispose()
$ms = New-Object System.IO.MemoryStream
$bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
$pngB64 = [Convert]::ToBase64String($ms.ToArray())
$ms.Dispose(); $bmp.Dispose()

$pngName = "dmv_/icons/dashboard_icon.png"
$ex = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/webresourceset?`$filter=name eq '$pngName'&`$select=webresourceid" -Headers $h
if ($ex.value.Count -gt 0) {
    Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/webresourceset($($ex.value[0].webresourceid))" -Headers $h -Method Patch `
        -Body ([System.Text.Encoding]::UTF8.GetBytes((@{ content = $pngB64 } | ConvertTo-Json)))
    Write-Host "  Updated: $pngName"
} else {
    $body = @{ name = $pngName; displayname = "dashboard icon PNG"; webresourcetype = 5; content = $pngB64 } | ConvertTo-Json
    Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/webresourceset" -Headers $h -Method Post `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
    Write-Host "  Created: $pngName"
}

# Add icons to solution
foreach ($n in @("dmv_/icons/dashboard.svg", "dmv_/icons/dashboard_icon.png")) {
    $wr = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/webresourceset?`$filter=name eq '$n'&`$select=webresourceid" -Headers $h
    if ($wr.value.Count -gt 0) {
        try {
            $solBody = @{ ComponentId = $wr.value[0].webresourceid; ComponentType = 61; SolutionUniqueName = $solutionName; AddRequiredComponents = $false } | ConvertTo-Json
            Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/AddSolutionComponent" -Headers $h -Method Post `
                -Body ([System.Text.Encoding]::UTF8.GetBytes($solBody)) | Out-Null
        } catch {}
    }
}

# ── Step 3: Add Dashboards Group to Sitemap ──
Write-Host "`n=== Step 3: Update Sitemap ==="
$sm = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/sitemaps($smId)?`$select=sitemapxml" -Headers $h
$xml = $sm.sitemapxml

if ($xml.Contains('nav_regdashboard')) {
    Write-Host "  Dashboard already in sitemap"
} else {
    # Insert a new Dashboards group right after the opening <Area ...>
    $dashGroup = '<Group Id="DashboardGroup" Title="Dashboards" IsProfile="false">' +
        '<SubArea Id="nav_regdashboard" Url="$webresource:dmv_/dashboard/registration_dashboard.html" ' +
        'Title="Registration Operations" Icon="$webresource:dmv_/icons/dashboard_icon.png" />' +
        '</Group>'

    # Insert after the <Area ...> opening tag (before the first <Group)
    $xml = $xml.Replace('<Group Id="CitizenGroup"', "$dashGroup<Group Id=`"CitizenGroup`"")
    Write-Host "  Added Dashboards group to sitemap"
}

# Patch sitemap
$escapedXml = $xml.Replace('"', '\"')
$rawBody = "{`"sitemapxml`":`"$escapedXml`"}"
Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/sitemaps($smId)" -Headers $h -Method Patch `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($rawBody))

# Verify
$verify = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/sitemaps($smId)?`$select=sitemapxml" -Headers $h
if ($verify.sitemapxml.Contains('nav_regdashboard')) {
    Write-Host "  Verified: Dashboard in sitemap"
} else {
    Write-Host "  WARNING: Dashboard not found in sitemap after patch!"
}

# ── Step 4: Add Web Resource to App Module ──
Write-Host "`n=== Step 4: Add to App Module ==="
$json = "{`"AppId`":`"$appId`",`"Components`":[{`"@odata.type`":`"Microsoft.Dynamics.CRM.webresource`",`"webresourceid`":`"$wrId`"}]}"
try {
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/AddAppComponents" -Method Post -Headers $h `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -UseBasicParsing | Out-Null
    Write-Host "  Added HTML web resource to app"
} catch {
    Write-Host "  Web resource add: $($_.ErrorDetails.Message.Substring(0, [Math]::Min(200, $_.ErrorDetails.Message.Length)))"
}

# ── Step 5: Publish ──
Write-Host "`n=== Step 5: Publish ==="
# Gather all web resource IDs for publishing
$allWrIds = @()
foreach ($n in @($wrName, "dmv_/icons/dashboard.svg", "dmv_/icons/dashboard_icon.png")) {
    $wr = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/webresourceset?`$filter=name eq '$n'&`$select=webresourceid" -Headers $h
    if ($wr.value.Count -gt 0) { $allWrIds += $wr.value[0].webresourceid }
}
$wrXml = ($allWrIds | ForEach-Object { "<webresource>{$_}</webresource>" }) -join ""
$paramXml = "<importexportxml>${wrXml}<sitemaps><sitemap>{$smId}</sitemap></sitemaps>" +
    "<appmodules><appmodule>{$appId}</appmodule></appmodules></importexportxml>"
$pubBody = @{ ParameterXml = $paramXml } | ConvertTo-Json
Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/PublishXml" -Headers $h -Method Post `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($pubBody))
Write-Host "  Published!"

Write-Host "`n=== DONE ==="
Write-Host "Dashboard is now available in the model-driven app under 'Dashboards > Registration Operations'"
Write-Host "Hard-refresh (Ctrl+Shift+R) the app to see changes."
