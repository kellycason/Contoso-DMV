###############################################################################
# 72_seed_appointment_demo_data.ps1
#
# Wipes existing dmv_appointment records and seeds a realistic spread of demo
# appointments across the next 3 weeks for the Appointment Calendar webresource.
#
# Distribution:
#   - 5 service types  (REAL ID, License Renewal, Vehicle Inspection,
#                       Road Test, Title Transfer)
#   - 6 statuses       (Scheduled, Confirmed, Checked In, Completed,
#                       No-Show, Cancelled)
#   - 3 DMV offices    (Eastside, Downtown, Westside)
#   - 7 demo contacts  (Maria, Sam, Alice, Brian, Carmen, Derek, Eliana)
#   - Hours 8 AM - 4 PM, Mon-Sat (skips Sun), 30-min slots
###############################################################################

$ErrorActionPreference = "Stop"
$envUrl = "https://orga381269e.crm9.dynamics.com"
$token  = az account get-access-token --resource $envUrl --query accessToken -o tsv

$h = @{
    Authorization              = "Bearer $token"
    "Content-Type"             = "application/json; charset=utf-8"
    "OData-MaxVersion"         = "4.0"
    "OData-Version"            = "4.0"
    "MSCRM.SolutionUniqueName" = "DMVDigitalServicesPortal"
}
$readH = @{ Authorization = "Bearer $token"; "OData-Version" = "4.0" }

# ── IDs ──────────────────────────────────────────────────────────────────────
$offices = @(
    "ecf2cc77-c339-f111-88b3-001dd801f94a",  # Eastside
    "c28b807b-c339-f111-88b4-001dd80340cd",  # Downtown
    "28c15a78-c339-f111-88b4-001dd80a6132"   # Westside
)
$contacts = @(
    "d2c23913-f238-f111-88b3-001dd801f94a",  # Maria Jennings
    "13d0cc9c-523f-f111-88b4-001dd80340cd",  # Sam Smith
    "46913312-f53f-f111-88b4-001dd80340cd",  # Alice Nguyen
    "6e913312-f53f-f111-88b4-001dd80340cd",  # Brian Patel
    "8b913312-f53f-f111-88b4-001dd80340cd",  # Carmen Ortiz
    "a0913312-f53f-f111-88b4-001dd80340cd",  # Derek Johnson
    "b1913312-f53f-f111-88b4-001dd80340cd"   # Eliana Rivera
)

# Choice values
$serviceTypes = @(100000000, 100000001, 100000002, 100000003, 100000004)  # REAL ID, License Renewal, Vehicle Inspection, Road Test, Title Transfer
$durations    = @{
    100000000 = 30   # REAL ID
    100000001 = 30   # License Renewal
    100000002 = 45   # Vehicle Inspection
    100000003 = 60   # Road Test
    100000004 = 30   # Title Transfer
}
$timeSlots = @(
    "8:00 AM","8:30 AM","9:00 AM","9:30 AM","10:00 AM","10:30 AM",
    "11:00 AM","11:30 AM","1:00 PM","1:30 PM","2:00 PM","2:30 PM",
    "3:00 PM","3:30 PM","4:00 PM"
)

# Status: weighted by recency
# Past   -> mostly Completed (3) + a few No-Show (4) / Cancelled (5)
# Today  -> Confirmed (1) / Checked In (2) / Scheduled (0)
# Future -> Scheduled (0) + Confirmed (1) + a few Cancelled (5)

# ── Step 1: Delete existing appointments ────────────────────────────────────
Write-Host "=== Step 1: Wipe existing appointments ===" -ForegroundColor Cyan
$existing = (Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_appointments?`$select=dmv_appointmentid&`$top=5000" -Headers $readH).value
Write-Host "  Found $($existing.Count) existing"
foreach ($a in $existing) {
    try {
        Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_appointments($($a.dmv_appointmentid))" -Method Delete -Headers $h -UseBasicParsing | Out-Null
    } catch {
        Write-Host "  WARN: could not delete $($a.dmv_appointmentid)" -ForegroundColor Yellow
    }
}
Write-Host "  Cleared." -ForegroundColor DarkGray

# ── Step 2: Build the seed plan ─────────────────────────────────────────────
Write-Host "`n=== Step 2: Build seed plan ===" -ForegroundColor Cyan

$rng = New-Object Random 42  # deterministic
$today = Get-Date -Hour 0 -Minute 0 -Second 0
$today = (Get-Date $today.ToString("yyyy-MM-dd"))

$plan = New-Object System.Collections.Generic.List[object]
$usedContacts = New-Object System.Collections.Generic.HashSet[string]

function Add-Appointment([DateTime]$date, [int]$daysFromToday) {
    # One appointment per day, picking from contacts that haven't been used yet.
    if ($usedContacts.Count -ge $contacts.Count) { return }   # everyone already booked

    $available = $contacts | Where-Object { -not $usedContacts.Contains($_) }
    if (-not $available) { return }

    $contact = $available[$rng.Next(0, @($available).Count)]
    [void]$usedContacts.Add($contact)

    $slot    = $timeSlots[$rng.Next(0, $timeSlots.Count)]
    $svc     = $serviceTypes[$rng.Next(0, $serviceTypes.Count)]
    $dur     = $durations[$svc]
    $office  = $offices[$rng.Next(0, $offices.Count)]

    # Status weighting based on time
    $status = 0
    if ($daysFromToday -lt 0) {
        $r = $rng.NextDouble()
        if     ($r -lt 0.70) { $status = 100000003 }   # Completed
        elseif ($r -lt 0.85) { $status = 100000004 }   # No-Show
        else                 { $status = 100000005 }   # Cancelled
    }
    elseif ($daysFromToday -eq 0) {
        $r = $rng.NextDouble()
        if     ($r -lt 0.30) { $status = 100000001 }
        elseif ($r -lt 0.50) { $status = 100000002 }
        elseif ($r -lt 0.70) { $status = 100000003 }
        elseif ($r -lt 0.90) { $status = 100000000 }
        else                 { $status = 100000005 }
    }
    else {
        $r = $rng.NextDouble()
        if     ($r -lt 0.55) { $status = 100000000 }
        elseif ($r -lt 0.90) { $status = 100000001 }
        else                 { $status = 100000005 }
    }

    $plan.Add(@{
        date     = $date
        time     = $slot
        duration = $dur
        service  = $svc
        status   = $status
        office   = $office
        contact  = $contact
    })
}

# Spread one appointment per contact across the current week (Mon-Sat),
# so every demo appointment is visible on the default weekly view.
$dow = [int]$today.DayOfWeek           # Sun=0, Mon=1, ..., Sat=6
$daysSinceMonday = if ($dow -eq 0) { 6 } else { $dow - 1 }
$weekStart = $today.AddDays(-$daysSinceMonday)

$candidateDays = @()
for ($i = 0; $i -lt 6; $i++) {          # Mon..Sat
    $date   = $weekStart.AddDays($i)
    $offset = ($date - $today).Days
    $candidateDays += ,@{ date = $date; offset = $offset }
}
# Shuffle the candidate days
$candidateDays = $candidateDays | Sort-Object { $rng.Next() }

foreach ($cd in $candidateDays) {
    Add-Appointment -date $cd.date -daysFromToday $cd.offset
    if ($usedContacts.Count -ge $contacts.Count) { break }
}

Write-Host "  Planned $($plan.Count) appointments for week of $($weekStart.ToShortDateString())" -ForegroundColor DarkGray

# ── Step 3: Create them ─────────────────────────────────────────────────────
Write-Host "`n=== Step 3: Creating appointments ===" -ForegroundColor Cyan

$created = 0
foreach ($p in $plan) {
    $body = @{
        "dmv_contactid@odata.bind"   = "/contacts($($p.contact))"
        "dmv_officeid@odata.bind"    = "/dmv_dmvoffices($($p.office))"
        dmv_servicetype              = $p.service
        dmv_status                   = $p.status
        dmv_appointmentdate          = $p.date.ToString("yyyy-MM-dd")
        dmv_appointmenttime          = $p.time
        dmv_duration                 = $p.duration
        dmv_confirmationsent         = ($p.status -ge 100000001)
        dmv_remindersent             = ($p.status -ge 100000001)
    }
    if ($p.status -eq 100000005) {
        $body.dmv_cancelreason = @("Schedule conflict","No longer needed","Rescheduling","Other") | Get-Random
    }
    if ($p.status -eq 100000002 -or $p.status -eq 100000003) {
        $body.dmv_checkintime = $p.date.ToString("yyyy-MM-ddT") + "14:00:00Z"
    }
    if ($p.status -eq 100000003) {
        $body.dmv_completiontime = $p.date.ToString("yyyy-MM-ddT") + "14:30:00Z"
    }

    $json = $body | ConvertTo-Json -Compress
    try {
        Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_appointments" `
            -Method Post -Headers $h `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -UseBasicParsing | Out-Null
        $created++
    } catch {
        Write-Host "  WARN: failed to create appt on $($p.date.ToShortDateString()) at $($p.time): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "`n=========================================" -ForegroundColor Green
Write-Host " SEEDED $created APPOINTMENTS" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "  Week: $($weekStart.ToShortDateString()) - $($weekStart.AddDays(5).ToShortDateString())"
Write-Host "  Service types: REAL ID, License Renewal, Vehicle Inspection, Road Test, Title Transfer"
Write-Host "  Offices: Eastside / Downtown / Westside"
Write-Host ""
