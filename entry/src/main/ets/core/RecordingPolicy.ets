export const MIN_RECORDING_DURATION_SECONDS: number = 4;

export function isRecordingTooShort(durationSeconds: number): boolean {
  return durationSeconds < MIN_RECORDING_DURATION_SECONDS;
}
