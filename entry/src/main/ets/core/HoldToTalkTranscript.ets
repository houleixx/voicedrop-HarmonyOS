/**
 * Cumulative ASR transcript holder for hold-to-talk voice commands.
 *
 * Volc ASR sends cumulative transcript snapshots — each partial/final replaces
 * the previous text. This class always keeps the newest snapshot, even when a
 * late partial follows an early final (mirrors Android `HoldToTalkTranscript`).
 *
 * Pure ArkTS — no UI or Kit dependencies. Safe to unit-test.
 */

export class HoldToTalkTranscript {
  private latestText: string = '';

  clear(): void {
    this.latestText = '';
  }

  accept(text: string, isFinal: boolean): void {
    const trimmed: string = text.trim();
    if (trimmed.length === 0) return;
    this.latestText = trimmed;
  }

  /** The most recent ASR snapshot (partial or final). */
  bestText(): string {
    return this.latestText;
  }

  /** Text to show in the feedback bubble. Falls back to "在听…" when empty. */
  bubbleText(): string {
    const text: string = this.bestText();
    return text.length > 0 ? text : '在听…';
  }
}
