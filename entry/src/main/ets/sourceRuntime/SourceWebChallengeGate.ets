export type SourceWebChallengeScope = 'browse' | 'search' | 'detail'

/** Public UI receipt contains no query, URL, settings or session secrets. */
export interface SourceWebChallengeReceipt {
  id: number
  sourceId: string
  scope: SourceWebChallengeScope
}

/** One challenge attempt, claimed once and consumed before retrying. No UI or transport owner. */
export class SourceWebChallengeGate {
  private sequence: number = 0
  private receipt: SourceWebChallengeReceipt | null = null
  private claimed: boolean = false
  private current: () => boolean = (): boolean => false
  private retry: () => Promise<void> = async (): Promise<void> => {}

  issue(sourceId: string, scope: SourceWebChallengeScope, eligible: boolean,
    current: () => boolean, retry: () => Promise<void>): SourceWebChallengeReceipt | null {
    this.clear()
    if (!eligible || !current()) return null
    const receipt: SourceWebChallengeReceipt = { id: ++this.sequence, sourceId, scope }
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
