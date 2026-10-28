export type SourceWebChallengeScope = 'browse' | 'search' | 'detail'

/** Public UI receipt contains no query, URL, settings or session secrets. */
export interface SourceWebChallengeReceipt {
  id: number
  sourceId: string
  scope: SourceWebChallengeScope
  allowClearanceRetry: boolean
  requestHandle?: string
}

/** One challenge attempt, claimed once and consumed before retrying. No UI or transport owner. */
export class SourceWebChallengeGate {
  private sequence: number = 0
  private receipt: SourceWebChallengeReceipt | null = null
  private claimed: boolean = false
  private current: () => boolean = (): boolean => false
  private retry: () => Promise<void> = async (): Promise<void> => {}

  issue(sourceId: string, scope: SourceWebChallengeScope, eligible: boolean,
    current: () => boolean, retry: () => Promise<void>, allowClearanceRetry: boolean = false,
    requestHandle?: string): SourceWebChallengeReceipt | null {
    this.clear()
    if (!eligible || !current()) return null
    const receipt: SourceWebChallengeReceipt = { id: ++this.sequence, sourceId, scope, allowClearanceRetry }
    if (requestHandle !== undefined) receipt.requestHandle = requestHandle
    this.receipt = receipt
    this.current = current
    this.retry = retry
    return receipt
  }

  claim(id: number, visible: boolean): boolean {
    if (!visible || this.receipt?.id !== id || this.claimed || !this.current()) return false
    this.claimed = true
    return true
  }

  isCurrentClaim(id: number): boolean {
    return this.receipt?.id === id && this.claimed && this.current()
  }

  cancel(id: number): boolean {
    if (this.receipt?.id !== id) return false
    this.clear()
    return true
  }

  async complete(id: number, visible: boolean): Promise<boolean> {
    if (this.receipt?.id !== id) return false
    const valid = visible && this.claimed && this.current()
    const retry = this.retry
    this.clear()
    if (!valid) return false
    await retry()
    return true
  }

  clear(): void {
    this.receipt = null
    this.claimed = false
    this.current = (): boolean => false
    this.retry = async (): Promise<void> => {}
  }
}

/** Diagnostic category only: no cookie names, values or lengths leave this helper. */
export function sourceClearanceCookieState(cookies: string): string {
  let count = 0
  let nonempty = false
  cookies.split(';').forEach((entry: string) => {
    const separator = entry.indexOf('=')
    if (separator < 0 || entry.slice(0, separator).trim() !== 'cf_clearance') return
    count += 1
    nonempty = entry.slice(separator + 1).trim().length > 0
  })
  if (count === 0) return 'missing'
  if (count > 1) return 'ambiguous'
  return nonempty ? 'present' : 'empty'
}

/** In-memory retry signal only; never a claim that the native request will pass. */
export function hasNewSourceClearance(previousCookies: string, currentCookies: string): boolean {
  const clearance = (cookies: string): string => {
    let value = ''
    let count = 0
    cookies.split(';').forEach((entry: string) => {
      const separator = entry.indexOf('=')
      if (separator < 0 || entry.slice(0, separator).trim() !== 'cf_clearance') return
      count += 1
      value = entry.slice(separator + 1).trim()
    })
    return count === 1 ? value : ''
  }
  const current = clearance(currentCookies)
  return current.length > 0 && current !== clearance(previousCookies)
}
