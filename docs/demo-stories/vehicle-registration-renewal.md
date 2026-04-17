# Demo Story: Vehicle Registration Renewal

## Scenario

Maria Jennings owns a 2024 Tesla Model S. Her registration (REG-2025-00891) expires **June 10, 2026** and is showing an amber "Expiring Soon" warning on the portal. She wants to renew online.

---

## Part 1: Citizen Portal (Maria's Perspective)

### Setup

1. Open the portal: `https://site-y5jzr.powerappsportals.us/`
2. Sign in as **Maria Jennings**
3. Navigate to **Vehicle Registration** (`/vehicle-registration`)

### What Maria Sees

- A list of her registered vehicles (Honda Accord 2023, Tesla Model S 2024)
- The Tesla shows **"Expires Jun 10, 2026"** in amber text
- Two buttons appear: **Renew** (primary) and **Renew at Office** (secondary)

### Demo Steps

1. Click **Renew** on the Tesla Model S row
2. A confirmation screen appears showing:
   - Vehicle: 2024 Tesla Model S
   - Current expiration: June 10, 2026
   - Renewal fee: **$50.00**
3. Click **Submit Renewal**
4. A success screen appears with the registration ID (REG-2025-00891) and a confirmation message

### What Happened Behind the Scenes (4 API Calls)

| Step | Action | Table | Key Fields |
|---|---|---|---|
| 1 | **Create new term** | `dmv_registrationterm` | Type = Renewal, Status = Pending, Start = today, End = today + 1 year |
| 2 | **Create payment** | `dmv_registrationpayment` | Amount = $50.00, Status = Unpaid, linked to new term |
| 3 | **Expire old term** | `dmv_registrationterm` | Old term → Status = Expired |
| 4 | **Update registration** | `dmv_vehicleregistration` | `currenttermid` → new term, Status = Active |

**Key point**: No new registration was created. REG-2025-00891 still exists — it just got a new child term stacked on top. The old term is preserved as history.

---

## Part 2: Back Office (Employee's Perspective)

### Setup

1. Open the model-driven app: `https://orga381269e.crm9.dynamics.com`
2. Navigate to **Vehicle Registrations** in the left nav
3. Find **REG-2025-00891** (Tesla Model S)

### What the Employee Sees

- Registration status: **Active**
- Current Term: points to the **new renewal term** (TERM-2026-XXXXX)
- The Terms sub-grid shows **two rows**:
  - Original term — Type: New, Status: **Expired**, ended 2026-06-10
  - Renewal term — Type: Renewal, Status: **Pending**, ends 2027-04-16

### Demo Steps — Process the Renewal

#### Step 1: Review the Payment

1. Click the **new renewal term** (TERM-2026-XXXXX) to open it
2. In the Payments sub-grid, open the payment record (PAY-2026-XXXXX)
3. You'll see:
   - Amount: **$50.00**
   - Total: **$50.00**
   - Payment Status: **Unpaid**
   - Payment Method: *(blank)*

#### Step 2: Mark Payment as Paid

1. Set **Payment Method** → Credit Card
2. Set **Payment Date** → today's date
3. Set **Payment Status** → **Paid**
4. **Save**

#### Step 3: Activate the Term

1. Go back to the term record (TERM-2026-XXXXX)
2. Change **Term Status** from Pending → **Active**
3. Optionally fill in **Sticker/Decal Number** (e.g., `STK-2026-84721`)
4. **Save**

#### Step 4: Stamp the Expiration Date (Portal Display)

1. Go back to the registration record (REG-2025-00891)
2. Update **Expiration Date** (`dmv_expirationdate`) to the new term's end date (e.g., `2027-04-16`)
3. **Save**

> **Why this step?** The portal reads `dmv_expirationdate` directly from the registration record (denormalized). Without this update, the portal would still show the old expiration date. In production, a Power Automate flow would handle this automatically.

### Final State

| Record | Field | Value |
|---|---|---|
| Registration REG-2025-00891 | Status | Active |
| Registration REG-2025-00891 | Current Term | → new renewal term |
| Registration REG-2025-00891 | Expiration Date | 2027-04-16 |
| Old Term | Status | Expired |
| New Term | Status | Active |
| New Term | Type | Renewal |
| New Term | End Date | 2027-04-16 |
| Payment | Status | Paid |
| Payment | Method | Credit Card |

---

## Talking Points for the Demo

- **"The registration is permanent — it represents the relationship between Maria and her Tesla. We never delete it."**
- **"Each renewal just adds a new term. The old term stays as a complete audit trail."**
- **"The employee sees the full history — every registration period, every payment, all in one place."**
- **"This is the same pattern real DMVs use: your registration number doesn't change when you renew, just the sticker and dates."**
- **"Right now the employee manually processes payment and activates the term. In production, payment processing and term activation would be automated with Power Automate."**

---

## Data Model Recap

```
dmv_vehicleregistration  ← permanent, never recreated
  │
  ├── Term 1 (New, Expired, 2025-06-10 → 2026-06-10)
  │     └── Payment 1 ($75, Paid)
  │
  └── Term 2 (Renewal, Active, 2026-04-16 → 2027-04-16)  ← NEW
        └── Payment 2 ($50, Paid)                          ← NEW
```

The `currenttermid` lookup on the registration always points to the latest active term (Term 2 after renewal).

---

## Quick Reference: Entity IDs (Maria's Tesla)

| Record | ID |
|---|---|
| Vehicle (Tesla Model S 2024) | `26def455-1d39-f111-88b4-001dd80340cd` |
| Registration (REG-2025-00891) | `b3d6565a-1d39-f111-88b3-001dd801f94a` |
| Original Term | `515dd7aa-cb39-f111-88b3-001dd801f94a` |
| New Renewal Term | *(created during demo)* |
| Payment | *(created during demo)* |
