import { useEffect, useRef, useState, useCallback } from 'react'
// @ts-expect-error - no types shipped
import { OmnichannelChatSDK } from '@microsoft/omnichannel-chat-sdk'
// @ts-expect-error - botframework-webchat ships its own types but as a single bundle
import ReactWebChat from 'botframework-webchat'
import './ChatWidget.css'

// Omnichannel widget config — Contact Center DMV Agent
const omnichannelConfig = {
  orgUrl: 'https://m-c118dfce-db8c-f011-a701-001dd80a8619.gov.omnichannelengagementhub.us',
  orgId: 'c118dfce-db8c-f011-a701-001dd80a8619',
  widgetId: '92729e5b-00a0-45bc-937d-ffec28f28748',
}

declare global {
  interface Window {
    __PORTAL_USER__?: { name?: string; id?: string } | null
    __DMV_DATA__?: any
  }
}

type Phase = 'closed' | 'connecting' | 'chatting' | 'error'

export default function ChatWidget() {
  const [phase, setPhase] = useState<Phase>('closed')
  const [unread, setUnread] = useState(0)
  const [error, setError] = useState<string | null>(null)
  const [directLine, setDirectLine] = useState<any>(null)
  const sdkRef = useRef<any>(null)
  const initStartedRef = useRef(false)
  const sessionStartedRef = useRef(false)
  const startInFlightRef = useRef(false)
  const phaseRef = useRef<Phase>('closed')
  useEffect(() => { phaseRef.current = phase }, [phase])

  const open = phase !== 'closed'

  const ensureSdk = useCallback(async () => {
    if (sdkRef.current) return sdkRef.current
    if (initStartedRef.current) {
      while (!sdkRef.current) await new Promise((r) => setTimeout(r, 50))
      return sdkRef.current
    }
    initStartedRef.current = true
    const chatSDK = new OmnichannelChatSDK(omnichannelConfig)
    await chatSDK.initialize()
    sdkRef.current = chatSDK
    return chatSDK
  }, [])

  const startSession = useCallback(async () => {
    if (startInFlightRef.current) return
    startInFlightRef.current = true
    setPhase('connecting')
    setError(null)
    try {
      const chatSDK = await ensureSdk()
      const optionalParams: any = {}

      const u = window.__PORTAL_USER__
      const citizen = window.__DMV_DATA__?.citizen
      const customContext: Record<string, { value: string; isDisplayable: boolean }> = {}
      if (u?.name) customContext['contactName'] = { value: u.name, isDisplayable: true }
      if (u?.id) customContext['portalContactId'] = { value: u.id, isDisplayable: false }
      if (citizen?.email) customContext['email'] = { value: citizen.email, isDisplayable: true }
      if (citizen?.phone) customContext['phone'] = { value: citizen.phone, isDisplayable: false }
      if (Object.keys(customContext).length > 0) optionalParams.customContext = customContext

      try {
        const reconnectCtx = await chatSDK.getChatReconnectContext?.()
        if (reconnectCtx?.reconnectId) optionalParams.reconnectId = reconnectCtx.reconnectId
      } catch { /* ignore */ }

      console.log('[ChatWidget] startChat begin', optionalParams)
      await chatSDK.startChat(optionalParams)
      console.log('[ChatWidget] startChat OK; creating adapter…')
      sessionStartedRef.current = true

      const adapter = await chatSDK.createChatAdapter()
      console.log('[ChatWidget] adapter ready')
      setDirectLine(adapter)

      try {
        chatSDK.onNewMessage?.((_msg: any) => {
          if (phaseRef.current !== 'chatting') setUnread((n) => n + 1)
        }, { rehydrate: true })
        chatSDK.onAgentEndSession?.(() => { /* keep transcript */ })
      } catch (e) { console.warn('[ChatWidget] event hookup warn', e) }

      setPhase('chatting')
    } catch (e: any) {
      console.error('[ChatWidget] startChat error', e)
      setError(e?.message || 'Unable to connect. Please try again.')
      setPhase('error')
    } finally {
      startInFlightRef.current = false
    }
  }, [ensureSdk])

  // First open → connect immediately, no pre-chat form
  const handleOpen = useCallback(() => {
    setUnread(0)
    if (phase === 'closed') {
      if (sessionStartedRef.current && directLine) {
        setPhase('chatting')
      } else {
        startSession()
      }
    }
  }, [phase, directLine, startSession])

  const handleClose = useCallback(() => {
    setPhase('closed')
    setUnread(0)
  }, [])

  const handleEndChat = useCallback(async () => {
    try {
      if (sessionStartedRef.current && sdkRef.current) await sdkRef.current.endChat()
    } catch { /* ignore */ }
    sessionStartedRef.current = false
    setDirectLine(null)
    setPhase('closed')
    setUnread(0)
  }, [])

  useEffect(() => {
    return () => {
      if (sessionStartedRef.current && sdkRef.current) {
        sdkRef.current.endChat?.().catch(() => {})
      }
    }
  }, [])

  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') handleClose() }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, handleClose])

  // BotFramework-WebChat theme: navy + red, matches site
  const styleOptions = {
    rootHeight: '100%',
    rootWidth: '100%',
    backgroundColor: 'transparent',

    bubbleBackground: '#ffffff',
    bubbleBorderColor: '#e2e8f0',
    bubbleBorderRadius: 16,
    bubbleBorderStyle: 'solid',
    bubbleBorderWidth: 1,
    bubbleTextColor: '#1e293b',
    bubbleFromUserBackground: '#1e3a5f',
    bubbleFromUserBorderColor: '#1e3a5f',
    bubbleFromUserBorderRadius: 16,
    bubbleFromUserTextColor: '#ffffff',
    bubbleMaxWidth: 280,
    bubbleMinHeight: 36,
    bubbleMinWidth: 60,

    avatarBorderRadius: '50%',
    avatarSize: 28,
    botAvatarBackgroundColor: '#1e3a5f',
    botAvatarInitials: 'DA',
    userAvatarInitials: '',

    sendBoxBackground: '#ffffff',
    sendBoxBorderTop: '1px solid #e2e8f0',
    sendBoxButtonColor: '#C42230',
    sendBoxButtonColorOnHover: '#a31c28',
    sendBoxButtonColorOnFocus: '#a31c28',
    sendBoxHeight: 56,
    sendBoxTextColor: '#1e293b',
    sendBoxPlaceholderColor: '#94a3b8',
    hideUploadButton: true,

    suggestedActionBackground: '#ffffff',
    suggestedActionBorderColor: '#e2e8f0',
    suggestedActionBorderRadius: 999,
    suggestedActionBorderStyle: 'solid',
    suggestedActionBorderWidth: 1,
    suggestedActionTextColor: '#334155',
    suggestedActionLayout: 'flow',
    suggestedActionDisabledBackground: '#f1f5f9',

    timestampColor: '#94a3b8',
    timestampFormat: 'relative',
    transcriptOverlayButtonBackground: '#1e3a5f',
    transcriptOverlayButtonBackgroundOnHover: '#152d4a',
    transcriptOverlayButtonColor: '#ffffff',
    accent: '#C42230',
    fontSizeSmall: '80%',
    primaryFont: '"Inter", "Segoe UI", -apple-system, BlinkMacSystemFont, sans-serif',
  }

  return (
    <>
      {/* Launcher FAB */}
      <button
        type="button"
        className={`dmv-chat-fab${open ? ' is-open' : ''}${unread > 0 ? ' has-unread' : ''}`}
        onClick={() => (open ? handleClose() : handleOpen())}
        aria-label={open ? 'Close chat' : 'Open chat assistant'}
        aria-haspopup="dialog"
      >
        <span className="dmv-chat-fab__ping" aria-hidden="true" />
        {unread > 0 && <span className="dmv-chat-fab__badge">{unread > 9 ? '9+' : unread}</span>}
        <svg className="dmv-chat-icon" viewBox="0 0 24 24" fill="none" aria-hidden="true">
          <path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"
                stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round"/>
        </svg>
        <svg className="dmv-chat-close-icon" viewBox="0 0 24 24" fill="none" aria-hidden="true">
          <path d="M6 6L18 18M6 18L18 6" stroke="currentColor" strokeWidth={2.4} strokeLinecap="round"/>
        </svg>
      </button>

      {/* Panel */}
      <div className={`dmv-chat-panel${open ? ' is-open' : ''}`} role="dialog" aria-label="Chat with DMV Assist">
        <header className="dmv-chat-panel__header">
          <div className="dmv-chat-panel__avatar" aria-hidden="true">
            <svg viewBox="0 0 24 24" fill="none">
              <path d="M12 2l2.39 4.84L20 8l-4 3.9.94 5.5L12 14.77 7.06 17.4 8 11.9 4 8l5.61-1.16L12 2z"
                    fill="currentColor"/>
            </svg>
            <span className="dmv-chat-panel__avatar-status" />
          </div>
          <div className="dmv-chat-panel__title">
            <div className="dmv-chat-panel__title-main">DMV Assist</div>
            <div className="dmv-chat-panel__title-sub">
              {phase === 'connecting' ? 'Connecting…'
                : phase === 'error' ? 'Connection error'
                : 'Online · Avg reply 30s'}
            </div>
          </div>
          {phase === 'chatting' && (
            <button className="dmv-chat-panel__icon-btn" onClick={handleEndChat} aria-label="End chat" title="End chat">
              <svg viewBox="0 0 24 24" fill="none">
                <path d="M9 6h6m-7 0v12a2 2 0 002 2h4a2 2 0 002-2V6m-8 0V4a2 2 0 012-2h4a2 2 0 012 2v2"
                  stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </button>
          )}
          <button className="dmv-chat-panel__icon-btn" onClick={handleClose} aria-label="Close chat">
            <svg viewBox="0 0 24 24" fill="none">
              <path d="M6 6L18 18M6 18L18 6" stroke="currentColor" strokeWidth={2} strokeLinecap="round"/>
            </svg>
          </button>
        </header>

        <div className="dmv-chat-panel__body">
          {phase === 'connecting' && (
            <div className="dmv-chat-loading">
              <div className="dmv-chat-loading__spinner" />
              <p>Connecting you with DMV Assist…</p>
            </div>
          )}

          {phase === 'error' && (
            <div className="dmv-chat-loading">
              <div className="dmv-chat-error-icon" aria-hidden="true">
                <svg viewBox="0 0 24 24" fill="none">
                  <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth={2}/>
                  <path d="M12 8v4M12 16h.01" stroke="currentColor" strokeWidth={2} strokeLinecap="round"/>
                </svg>
              </div>
              <p className="dmv-chat-loading__error-text">{error}</p>
              <button type="button" className="dmv-chat-retry-btn"
                      onClick={() => { setPhase('closed'); setTimeout(handleOpen, 50) }}>
                Try again
              </button>
            </div>
          )}

          {phase === 'chatting' && directLine && (
            <div className="dmv-chat-webchat">
              <ReactWebChat
                directLine={directLine}
                styleOptions={styleOptions}
                userID={window.__PORTAL_USER__?.id || 'guest'}
                username={window.__PORTAL_USER__?.name || 'Guest'}
                locale="en-US"
              />
            </div>
          )}
        </div>

        <footer className="dmv-chat-panel__footer">
          Secure · Official Contoso DMV Portal
        </footer>
      </div>
    </>
  )
}
