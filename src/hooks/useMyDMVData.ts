import { useState, useEffect } from 'react'

/* ── Exported interfaces ── */

export interface CitizenProfile {
  id: string
  fullName: string
  email: string
  address: string
  city?: string
  state?: string
  zip?: string
  phone: string
}

export interface DriverLicense {
  id: string
  licenseNumber: string
  status: string
  expirationDate: string
  realIdCompliant: boolean
  licenseClass: string
  issueDate: string
}

export interface VehicleWithReg {
  id: string
  vin: string
  year: string
  make: string
  model: string
  plateNumber: string
  color: string
  insuranceStatus: string
  insuranceExpiry: string
  registration: {
    id: string
    status: string
    expirationDate: string
    totalDue: number
    paymentStatus: string
  } | null
}

export interface Transaction {
  id: string
  transactionId: string
  type: string
  date: string
  status: string
  amount: string
}

export interface ActionItem {
  id: number
  type: string
  detail: string
  due: string
  urgency: 'high' | 'medium'
}

export interface MyDMVData {
  loading: boolean
  error: string | null
  citizen: CitizenProfile | null
  license: DriverLicense | null
  vehicles: VehicleWithReg[]
  transactions: Transaction[]
  actions: ActionItem[]
}

declare global {
  interface Window {
    __DMV_DATA__: {
      citizen: CitizenProfile
      license: DriverLicense | null
      vehicles: Array<{
        id: string; vin: string; year: string; make: string; model: string
        plateNumber: string; color: string; insuranceStatus: string; insuranceExpiry: string
      }>
      registrations: Array<{
        id: string; regId: string; status: string; expirationDate: string
        totalDue: number; paymentStatus: string; vehicleId: string
      }>
      transactions: Array<{
        id: string; transactionId: string; type: string; date: string
        status: string; amount: number
      }>
    } | null
  }
}

/* ── Hook ── */

export function useMyDMVData(contactId: string | null): MyDMVData {
  const [data, setData] = useState<MyDMVData>({
    loading: true, error: null, citizen: null, license: null,
    vehicles: [], transactions: [], actions: [],
  })

  useEffect(() => {
    if (!contactId) {
      setData({ loading: false, error: null, citizen: null, license: null, vehicles: [], transactions: [], actions: [] })
      return
    }

    const raw = window.__DMV_DATA__
    if (!raw) {
      setData({ loading: false, error: 'No DMV data found for this account.', citizen: null, license: null, vehicles: [], transactions: [], actions: [] })
      return
    }

    // Liquid injects picklist values as their underlying integer. Translate to labels the UI expects.
    const regStatusLabel = (s: string | number): string => {
      const code = String(s ?? '').trim()
      switch (code) {
        case '100000000': return 'Active'
        case '100000001': return 'Expired'
        case '100000002': return 'Suspended'
        case '100000003': return 'Cancelled'
        case '100000004': return 'Pending'
        case '100000005': return 'Rejected'
        case '100000006': return 'Submitted'
      }
      // Already a label? Pass through.
      if (/^(Active|Expired|Suspended|Cancelled|Pending|Rejected|Submitted)$/i.test(code)) {
        return code.charAt(0).toUpperCase() + code.slice(1).toLowerCase()
      }
      return code || 'Unknown'
    }
    const insStatusLabel = (s: string | number): string => {
      const code = String(s ?? '').trim()
      switch (code) {
        case '100000000': return 'Verified'
        case '100000001': return 'Unverified'
        case '100000002': return 'Lapsed'
        case '100000003': return 'Expired'
      }
      if (/^(Verified|Unverified|Lapsed|Expired)$/i.test(code)) {
        return code.charAt(0).toUpperCase() + code.slice(1).toLowerCase()
      }
      return code || 'Unverified'
    }

    // Build registration lookup by vehicleId
    const regMap: Record<string, typeof raw.registrations[0]> = {}
    for (const r of raw.registrations) {
      if (!regMap[r.vehicleId]) regMap[r.vehicleId] = r
    }

    // Map vehicles with their registrations
    const vehicles: VehicleWithReg[] = raw.vehicles.map((v) => {
      const reg = regMap[v.id]
      let regStatus = reg ? regStatusLabel(reg.status) : null
      // Fallback: if status came through blank/Unknown but we have a future expiration, assume Active
      if (reg && (!regStatus || regStatus === 'Unknown') && reg.expirationDate) {
        const exp = new Date(reg.expirationDate)
        if (!isNaN(exp.getTime())) {
          regStatus = exp.getTime() > Date.now() ? 'Active' : 'Expired'
        }
      }
      return {
        ...v,
        insuranceStatus: insStatusLabel(v.insuranceStatus),
        registration: reg
          ? { id: reg.id, status: regStatus || 'Active', expirationDate: reg.expirationDate, totalDue: reg.totalDue, paymentStatus: reg.paymentStatus }
          : null,
      }
    })

    // Compute action items
    const now = new Date()
    const actions: ActionItem[] = []
    let aid = 1
    for (const v of vehicles) {
      if (v.registration) {
        const exp = new Date(v.registration.expirationDate)
        const days = Math.ceil((exp.getTime() - now.getTime()) / (1000 * 60 * 60 * 24))
        if (days > 0 && days <= 60) {
          actions.push({ id: aid++, type: 'Registration Renewal', detail: `${v.year} ${v.make} ${v.model}`, due: v.registration.expirationDate, urgency: days <= 30 ? 'high' : 'medium' })
        }
      }
    }

    // Map transactions
    const transactions: Transaction[] = raw.transactions.map((t) => ({
      id: t.id,
      transactionId: t.transactionId,
      type: t.type,
      date: t.date,
      status: t.status,
      amount: t.amount != null ? `$${Number(t.amount).toFixed(2)}` : '$0.00',
    }))

    setData({
      loading: false, error: null,
      citizen: raw.citizen,
      license: raw.license,
      vehicles, transactions, actions,
    })
  }, [contactId])

  return data
}
