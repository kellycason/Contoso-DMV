<#
  26_create_spa_route_pages.ps1
  Creates Power Pages web pages for each React Router route so that
  direct-link / deep-link navigation works (avoids 404 on refresh or
  email links like /documents).

  Each route gets:
    1. A root mspp_webpage (isroot=true, partial URL, parent = Home root)
    2. A content mspp_webpage (isroot=false, same copy as Home content page)
#>

$envUrl   = "https://orga381269e.crm9.dynamics.com"
$token    = az account get-access-token --resource $envUrl --query accessToken -o tsv
$writeH = @{
    Authorization              = "Bearer $token"
    "Content-Type"             = "application/json; charset=utf-8"
    "OData-MaxVersion"         = "4.0"
    "OData-Version"            = "4.0"
    "MSCRM.SolutionUniqueName" = "DMVDigitalServicesPortal"
}
$readH = @{
    Authorization    = "Bearer $token"
    "OData-MaxVersion" = "4.0"
    "OData-Version"  = "4.0"
}

# --- Known IDs ---
$websiteId       = "461a50ae-9496-419e-a58b-14d56165b009"
$homeRootId      = "f96dc62c-ea87-4095-81e4-ac3240f624d6"
$homeContentId   = "8bb22454-d80b-4458-84a7-d3c604ad35c0"
$pageTemplateId  = "19161a0b-40bc-4386-a843-a1cafe516fa8"
$publishStateId  = "ba33c999-8687-42f5-84ef-4faf297ad111"
$languageId      = "752b3b1f-360c-4132-b154-34e0c7b91b68"

# --- Get the SPA shell HTML from the Home content page ---
$homePage = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/mspp_webpages($homeContentId)?`$select=mspp_copy" -Headers $readH
$spaCopy  = $homePage.mspp_copy
Write-Host "SPA shell length: $($spaCopy.Length) chars"

# --- Routes to register ---
# Format: partial-url, display-name
$routes = @(
    @("my-dmv",               "My DMV"),
    @("license-renewal",      "License Renewal"),
    @("vehicle-registration", "Vehicle Registration"),
    @("real-id",              "Real ID"),
    @("appointments",         "Appointments"),
    @("documents",            "Documents"),
    @("faq",                  "FAQ"),
    @("dealer",               "Dealer Dashboard"),
    @("dealer/elt",           "Electronic Lien & Title"),
    @("dealer/bulk",          "Bulk Registration"),
    @("dealer/temp-tags",     "Temporary Tags")
)

foreach ($route in $routes) {
    $partialUrl  = $route[0]
    $displayName = $route[1]

    # Check if a root page already exists for this partial URL
    $existing = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/mspp_webpages?`$filter=mspp_websiteid/mspp_websiteid eq '$websiteId' and mspp_partialurl eq '$partialUrl' and mspp_isroot eq true&`$select=mspp_webpageid,mspp_name&`$top=1" -Headers $readH
    if ($existing.value.Count -gt 0) {
        Write-Host "SKIP  /$partialUrl — already exists (id=$($existing.value[0].mspp_webpageid))"
        continue
    }

    # Determine parent: nested routes like dealer/elt need dealer as parent
    $parentId = $homeRootId
    if ($partialUrl -match '/') {
        $parentSlug = $partialUrl.Split('/')[0]
        $partialUrl = $partialUrl.Split('/')[1]  # only the leaf segment
        $parentLookup = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/mspp_webpages?`$filter=mspp_websiteid/mspp_websiteid eq '$websiteId' and mspp_partialurl eq '$parentSlug' and mspp_isroot eq true&`$select=mspp_webpageid&`$top=1" -Headers $readH
        if ($parentLookup.value.Count -gt 0) {
            $parentId = $parentLookup.value[0].mspp_webpageid
        }
    }

    # 1) Create root web page
    $rootBody = @{
        mspp_name                               = $displayName
        mspp_partialurl                          = $partialUrl
        mspp_isroot                              = $true
        mspp_hiddenfromsitemap                   = $true
        "mspp_websiteid@odata.bind"              = "/mspp_websites($websiteId)"
        "mspp_parentpageid@odata.bind"           = "/mspp_webpages($parentId)"
        "mspp_pagetemplateid@odata.bind"          = "/mspp_pagetemplates($pageTemplateId)"
        "mspp_publishingstateid@odata.bind"       = "/mspp_publishingstates($publishStateId)"
    } | ConvertTo-Json -Depth 2

    $rootResp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/mspp_webpages" `
        -Method Post -Headers $writeH `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($rootBody)) -UseBasicParsing
    $rootId = ($rootResp.Headers["OData-EntityId"] | Select-Object -First 1) -replace '.*\(([^)]+)\).*','$1'
    Write-Host "ROOT  /$($route[0]) — $rootId"

    # 2) Create content (localized) web page
    $contentBody = @{
        mspp_name                               = $displayName
        mspp_partialurl                          = $partialUrl
        mspp_isroot                              = $false
        mspp_copy                                = $spaCopy
        mspp_hiddenfromsitemap                   = $true
        "mspp_websiteid@odata.bind"              = "/mspp_websites($websiteId)"
        "mspp_parentpageid@odata.bind"           = "/mspp_webpages($parentId)"
        "mspp_rootwebpageid@odata.bind"           = "/mspp_webpages($rootId)"
        "mspp_pagetemplateid@odata.bind"          = "/mspp_pagetemplates($pageTemplateId)"
        "mspp_publishingstateid@odata.bind"       = "/mspp_publishingstates($publishStateId)"
        "mspp_webpagelanguageid@odata.bind"       = "/mspp_websitelanguages($languageId)"
    } | ConvertTo-Json -Depth 2

    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/mspp_webpages" `
        -Method Post -Headers $writeH `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($contentBody)) -UseBasicParsing | Out-Null
    Write-Host "CONTENT /$($route[0]) — done"
}

Write-Host "`nAll SPA route pages created. Deep links should now work."
