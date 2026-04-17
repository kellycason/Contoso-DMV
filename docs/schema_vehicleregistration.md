# Vehicle Registration Data Model

A lifecycle-based design that separates the **parent registration**, each **registration period (term)**, and **payment** into three focused tables.

---

## Table Overview

```
dmv_vehicleregistration  (parent – one per vehicle/owner combo)
  │
  ├──► dmv_registrationterm  (one per period: initial, renewal, transfer)
  │       │
  │       └──► dmv_registrationpayment  (one per term)
  │
  └── dmv_currenttermid ──► points to the active term
```

---

## 1. Vehicle Registration (parent)

**Entity**: `dmv_vehicleregistration`
**Entity Set**: `dmv_vehicleregistrations`
**Primary ID**: `dmv_vehicleregistrationid`
**Primary Name**: `dmv_registrationid`

This is the long-lived record that represents "Vehicle X is registered to Contact Y." It does **not** hold dates, fees, or sticker numbers — those live on the term.

| Column | Display Name | Type | Required | Notes |
|---|---|---|---|---|
| `dmv_registrationid` | Registration ID | String | Yes | e.g. `REG-2026-00001` |
| `dmv_vehicleid` | Vehicle | Lookup → `dmv_vehicle` | Yes | |
| `dmv_regcontactid` | Registrant (Contact) | Lookup → `contact` | No | Citizen registrant |
| `dmv_dealeracctid` | Registrant (Dealer) | Lookup → `account` | No | Dealer registrant |
| `dmv_regstatus` | Registration Status | Picklist | Yes | Overall status |
| `dmv_currenttermid` | Current Term | Lookup → `dmv_registrationterm` | No | Points to active/latest term |
| `dmv_county` | County | String | No | |
| `dmv_notes` | Notes | Memo | No | |

### Registration Status (`dmv_regstatus`)

| Value | Label |
|---|---|
| 100000000 | Active |
| 100000001 | Expired |
| 100000002 | Pending Payment |
| 100000003 | Pending Inspection |
| 100000004 | Suspended |
| 100000005 | Cancelled |

> **Deprecated columns** (still on the table, no longer used by the app): `dmv_effectivedate`, `dmv_expirationdate`, `dmv_regyear`, `dmv_fee`, `dmv_latefee`, `dmv_totaldue`, `dmv_paymentstatus`, `dmv_paymentmethod`, `dmv_paymentdate`, `dmv_paymenttransactionid`, `dmv_stickernumber`, `dmv_daystoexpiration`, `dmv_renewaleligible`, `dmv_onlineeligible`, `dmv_submitteddate`.

---

## 2. Registration Term

**Entity**: `dmv_registrationterm`
**Entity Set**: `dmv_registrationterms`
**Primary ID**: `dmv_registrationtermid`
**Primary Name**: `dmv_termnumber`

Each row represents one registration period. A new registration creates the first term; each renewal creates an additional term. **Old terms are never overwritten.**

| Column | Display Name | Type | Required | Notes |
|---|---|---|---|---|
| `dmv_termnumber` | Term Number | String | Yes | e.g. `TERM-2026-00001` |
| `dmv_vehicleregistrationid` | Vehicle Registration | Lookup → `dmv_vehicleregistration` | Yes | Parent registration |
| `dmv_termtype` | Term Type | Picklist | Yes | |
| `dmv_termstatus` | Term Status | Picklist | Yes | |
| `dmv_startdate` | Start Date | DateTime | Yes | Period begins |
| `dmv_enddate` | End Date | DateTime | Yes | Period expires |
| `dmv_issuedate` | Issue Date | DateTime | No | When term was issued |
| `dmv_stickernumber` | Sticker/Decal Number | String | No | Unique per term |

### Term Type (`dmv_termtype`)

| Value | Label |
|---|---|
| 100000000 | New |
| 100000001 | Renewal |
| 100000002 | Transfer |

### Term Status (`dmv_termstatus`)

| Value | Label |
|---|---|
| 100000000 | Active |
| 100000001 | Pending |
| 100000002 | Expired |

---

## 3. Registration Payment

**Entity**: `dmv_registrationpayment`
**Entity Set**: `dmv_registrationpayments`
**Primary ID**: `dmv_registrationpaymentid`
**Primary Name**: `dmv_paymentref`

One payment per term. Intentionally simplified for demo — no partial payments or installment plans.

| Column | Display Name | Type | Required | Notes |
|---|---|---|---|---|
| `dmv_paymentref` | Payment Reference | String | Yes | e.g. `PAY-2026-00001` |
| `dmv_registrationtermid` | Registration Term | Lookup → `dmv_registrationterm` | Yes | Which term this pays for |
| `dmv_amount` | Amount | Money | No | Base registration fee |
| `dmv_latefee` | Late Fee | Money | No | Additional late fee |
| `dmv_total` | Total | Money | No | amount + latefee |
| `dmv_paymentstatus` | Payment Status | Picklist | Yes | |
| `dmv_paymentmethod` | Payment Method | Picklist | No | |
| `dmv_paymentdate` | Payment Date | DateTime | No | When payment was received |
| `dmv_transactionid` | Transaction ID | String | No | External payment ref |

### Payment Status (`dmv_paymentstatus`)

| Value | Label |
|---|---|
| 100000000 | Unpaid |
| 100000001 | Paid |
| 100000002 | Refunded |
| 100000003 | Waived |

### Payment Method (`dmv_paymentmethod`)

| Value | Label |
|---|---|
| 100000000 | Credit Card |
| 100000001 | eCheck |
| 100000002 | Cash |
| 100000003 | Money Order |

---

## Relationships

```
dmv_vehicleregistration  1 ──── * dmv_registrationterm
dmv_registrationterm     1 ──── 1 dmv_registrationpayment
dmv_vehicleregistration.dmv_currenttermid ──► dmv_registrationterm (active term)
```

| From | Column | To | Cardinality |
|---|---|---|---|
| `dmv_registrationterm` | `dmv_vehicleregistrationid` | `dmv_vehicleregistration` | Many → One |
| `dmv_registrationpayment` | `dmv_registrationtermid` | `dmv_registrationterm` | One → One |
| `dmv_vehicleregistration` | `dmv_currenttermid` | `dmv_registrationterm` | Shortcut to active term |

---

## How Renewal Works

### New Registration

```
1. Create dmv_vehicleregistration
     dmv_registrationid = "REG-2026-00001"
     dmv_regstatus = 100000002 (Pending Payment)
     dmv_vehicleid@odata.bind = "/dmv_vehicles({id})"
     dmv_regcontactid@odata.bind = "/contacts({id})"

2. Create dmv_registrationterm
     dmv_termnumber = "TERM-2026-00001"
     dmv_termtype = 100000000 (New)
     dmv_termstatus = 100000001 (Pending)
     dmv_startdate = "2026-04-16T00:00:00Z"
     dmv_enddate = "2027-04-16T00:00:00Z"
     dmv_vehicleregistrationid@odata.bind = "/dmv_vehicleregistrations({regId})"

3. Create dmv_registrationpayment
     dmv_paymentref = "PAY-2026-00001"
     dmv_amount = 75.00
     dmv_total = 75.00
     dmv_paymentstatus = 100000000 (Unpaid)
     dmv_registrationtermid@odata.bind = "/dmv_registrationterms({termId})"

4. Update dmv_vehicleregistration
     dmv_currenttermid@odata.bind = "/dmv_registrationterms({termId})"
```

### Renewal

```
1. Create a NEW dmv_registrationterm
     dmv_termnumber = "TERM-2026-00042"
     dmv_termtype = 100000001 (Renewal)
     dmv_termstatus = 100000001 (Pending)
     dmv_startdate = "2027-04-16T00:00:00Z"
     dmv_enddate = "2028-04-16T00:00:00Z"
     dmv_vehicleregistrationid@odata.bind = "/dmv_vehicleregistrations({regId})"

2. Create dmv_registrationpayment for the new term
     dmv_amount = 50.00
     dmv_total = 50.00
     dmv_paymentstatus = 100000000 (Unpaid)

3. Mark old term as Expired
     PATCH dmv_registrationterms({oldTermId})
     dmv_termstatus = 100000002 (Expired)

4. Update parent to point to the new term
     PATCH dmv_vehicleregistrations({regId})
     dmv_currenttermid@odata.bind = "/dmv_registrationterms({newTermId})"
     dmv_regstatus = 100000000 (Active)   ← once paid
```

**Key rule**: Previous terms and payments are **never deleted or overwritten**. The full history is always available by querying all terms for a registration.

---

## Web API Examples

**Query terms for a registration:**
```
/_api/dmv_registrationterms?$filter=_dmv_vehicleregistrationid_value eq {regId}&$orderby=dmv_startdate desc
```

**Query payment for a term:**
```
/_api/dmv_registrationpayments?$filter=_dmv_registrationtermid_value eq {termId}
```

**Expand current term from registration:**
```
/_api/dmv_vehicleregistrations({regId})?$expand=dmv_currenttermid($select=dmv_termnumber,dmv_startdate,dmv_enddate,dmv_termstatus)
```
