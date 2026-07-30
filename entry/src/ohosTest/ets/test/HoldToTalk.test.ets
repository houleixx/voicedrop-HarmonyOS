import { describe, expect, it } from '@ohos/hypium';
import { CommandGestureGate, CommandGestureState } from '../../../main/ets/core/CommandGestureGate';
import { HoldToTalkTranscript } from '../../../main/ets/core/HoldToTalkTranscript';

export default function holdToTalkTest() {
  describe('HoldToTalk', () => {
    it('movesFromTouchDownThroughFinalRecognition', 0, () => {
      const gate: CommandGestureGate = new CommandGestureGate();
      expect(gate.beginPress()).assertTrue();
      expect(gate.currentState()).assertEqual(CommandGestureState.PRIMING);
      expect(gate.confirmLongPress()).assertTrue();
      expect(gate.currentState()).assertEqual(CommandGestureState.TALKING);
      expect(gate.beginFinish()).assertTrue();
      expect(gate.currentState()).assertEqual(CommandGestureState.FINISHING);
      gate.complete();
      expect(gate.currentState()).assertEqual(CommandGestureState.IDLE);
    });

    it('waitsForPrimedMicrophoneReleaseBeforeQuickTapHandoff', 0, () => {
      const gate: CommandGestureGate = new CommandGestureGate();
      expect(gate.beginPress()).assertTrue();
      expect(gate.beginHandoff()).assertTrue();
      expect(gate.currentState()).assertEqual(CommandGestureState.HANDOFF);
      expect(gate.beginPress()).assertFalse();
      gate.complete();
      expect(gate.currentState()).assertEqual(CommandGestureState.IDLE);
    });

    it('keepsLatestNonEmptyCumulativeTranscript', 0, () => {
      const transcript: HoldToTalkTranscript = new HoldToTalkTranscript();
      transcript.accept('前半句', false);
      transcript.accept('前半句和后半句', true);
      transcript.accept('  ', false);
      expect(transcript.bestText()).assertEqual('前半句和后半句');
    });
  });
}
