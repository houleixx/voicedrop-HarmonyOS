/**
 * State machine for the home record / voice-command gesture.
 *
 * Mirrors Android `CommandGestureGate` to keep re-entry rules consistent:
 *  - A new press is accepted only from IDLE.
 *  - A long-press confirmation is accepted only from PRIMING.
 *  - A handoff (quick tap → recording) is accepted only from PRIMING.
 *  - Finalization is accepted only from TALKING.
 *  - Cancelling a pending press is allowed from PRIMING / HANDOFF
 *    without interrupting command finalization.
 *
 * Pure ArkTS — no UI or Kit dependencies. Safe to unit-test.
 */

export enum CommandGestureState {
  IDLE,
  PRIMING,
  TALKING,
  FINISHING,
  HANDOFF
}

export class CommandGestureGate {
  private state: CommandGestureState = CommandGestureState.IDLE;

  /** Touch-down: accept the press only from IDLE. */
  beginPress(): boolean {
    if (this.state !== CommandGestureState.IDLE) return false;
    this.state = CommandGestureState.PRIMING;
    return true;
  }

  /** Long-press timer fired: transition PRIMING → TALKING. */
  confirmLongPress(): boolean {
    if (this.state !== CommandGestureState.PRIMING) return false;
    this.state = CommandGestureState.TALKING;
    return true;
  }

  /** Quick tap released: transition PRIMING → HANDOFF (will start recording). */
  beginHandoff(): boolean {
    if (this.state !== CommandGestureState.PRIMING) return false;
    this.state = CommandGestureState.HANDOFF;
    return true;
  }

  /** Long-press released: transition TALKING → FINISHING. */
  beginFinish(): boolean {
    if (this.state !== CommandGestureState.TALKING) return false;
    this.state = CommandGestureState.FINISHING;
    return true;
  }

  /** Gesture fully complete (command sent or recording started): → IDLE. */
  complete(): void {
    this.state = CommandGestureState.IDLE;
  }

  /**
   * Cancel a pending press or handoff without interrupting command
   * finalization. Allowed from PRIMING and HANDOFF only.
   */
  cancelPendingPress(): void {
    if (this.state === CommandGestureState.PRIMING ||
        this.state === CommandGestureState.HANDOFF) {
      this.state = CommandGestureState.IDLE;
    }
  }

  /** Hard cancel: always returns to IDLE. */
  cancel(): void {
    this.state = CommandGestureState.IDLE;
  }

  /** Exposed for tests and diagnostics. */
  currentState(): CommandGestureState {
    return this.state;
  }
}
