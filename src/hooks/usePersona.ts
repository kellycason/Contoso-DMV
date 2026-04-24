import { useEffect, useState, useCallback } from 'react'

export type Persona = 'citizen' | 'dealer'

const STORAGE_KEY = 'dmv_demo_persona'

function readInitial(): Persona {
  // URL override: ?as=dealer or ?as=citizen
  try {
    const params = new URLSearchParams(window.location.search)
    const fromUrl = params.get('as')
    if (fromUrl === 'dealer' || fromUrl === 'citizen') {
      window.localStorage.setItem(STORAGE_KEY, fromUrl)
      return fromUrl
    }
    const stored = window.localStorage.getItem(STORAGE_KEY)
    if (stored === 'dealer' || stored === 'citizen') return stored
  } catch { /* SSR or storage blocked */ }
  return 'citizen'
}

/**
 * usePersona — demo-only toggle between citizen and dealer header/nav.
 *
 * In production this would be driven by the signed-in contact's web role(s).
 * For the demo we hardcode a single toggle so one logged-in user can present
 * both experiences on-stage without signing in and out.
 */
export function usePersona(): { persona: Persona; setPersona: (p: Persona) => void; toggle: () => void } {
  const [persona, setPersonaState] = useState<Persona>(() => readInitial())

  useEffect(() => {
    const onStorage = (e: StorageEvent) => {
      if (e.key === STORAGE_KEY && (e.newValue === 'citizen' || e.newValue === 'dealer')) {
        setPersonaState(e.newValue)
      }
    }
    window.addEventListener('storage', onStorage)
    return () => window.removeEventListener('storage', onStorage)
  }, [])

  const setPersona = useCallback((p: Persona) => {
    try { window.localStorage.setItem(STORAGE_KEY, p) } catch { /* ignore */ }
    setPersonaState(p)
  }, [])

  const toggle = useCallback(() => {
    setPersona(persona === 'citizen' ? 'dealer' : 'citizen')
  }, [persona, setPersona])

  return { persona, setPersona, toggle }
}

/**
 * Hardcoded dealer identity used when persona=dealer. In production these
 * would come from the logged-in contact's parentcustomerid → account lookup.
 */
export const DEMO_DEALER = {
  accountId: '850e5195-523f-f111-88b3-001dd801f94a', // Contoso Motors
  accountName: 'Contoso Motors',
  contactId:  '13d0cc9c-523f-f111-88b4-001dd80340cd', // Sam Smith
  contactName: 'Sam Smith',
  jobTitle: 'Sales & Registration Manager',
  phone: '(555) 314-1593',
  email: 'kellycason+sam@microsoft.com',
}
