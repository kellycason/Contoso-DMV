declare global {
  interface Window {
    __PORTAL_USER__: { name: string; id: string } | null
  }
}

export interface AuthState {
  isAuthenticated: boolean
  userName: string | null
}

export function useAuth(): AuthState {
  const user = window.__PORTAL_USER__
  if (user && user.name) {
    return { isAuthenticated: true, userName: user.name }
  }
  return { isAuthenticated: false, userName: null }
}
