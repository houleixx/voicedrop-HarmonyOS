/**
 * Pure UI logic for the recording session — extracted for testability.
 * No ArkUI dependencies; safe to unit-test.
 */

export const WAVEFORM_PATTERN: number[] =
  [0.30, 0.56, 0.82, 0.48, 0.95, 0.65, 0.38, 0.74, 0.52, 0.86, 0.34, 0.62, 0.44];

const MAX_BARS: number = 13;
const BAR_FRAME: number = 46;
const BAR_MIN: number = 6;
const RECORD_RED: string = '#E5392E';
const WARM_PINK: string = '#EBA89F';
const LIGHT_PINK: string = '#E5C8C3';
const MAX_AMPLITUDE: number = 32767;
const NOISE_FLOOR: number = 0.015;
const RESPONSE_EXPONENT: number = 0.35;

export function formatRecordingTime(seconds: number): string {
  const safeSeconds: number = Math.max(0, Math.floor(seconds));
  const minutes: number = Math.floor(safeSeconds / 60);
  const remainingSeconds: number = safeSeconds % 60;
  return `${minutes.toString().padStart(2, '0')}:${remainingSeconds.toString().padStart(2, '0')}`;
}

/**
 * Convert the AVRecorder PCM peak to 0...1, remove the microphone noise floor,
 * and apply the same visual response curve as Android.
 */
export function normalizeAmplitude(amplitude: number): number {
  const normalized: number = Math.max(0, Math.min(1, amplitude / MAX_AMPLITUDE));
  if (normalized <= NOISE_FLOOR) return 0;
  const audible: number = (normalized - NOISE_FLOOR) / (1 - NOISE_FLOOR);
  return Math.pow(audible, RESPONSE_EXPONENT);
}

export function waveBarFrac(base: number, activeLevel: number): number {
  const level: number = Math.max(0, Math.min(1, activeLevel));
  return base * Math.min(1, 0.06 + level * 1.30);
}

export function waveBarHeight(frac: number): number {
  return Math.max(BAR_MIN, Math.floor(BAR_FRAME * frac));
}

export function waveBarColor(frac: number): string {
  if (frac > 0.6) return RECORD_RED;
  if (frac > 0.3) return WARM_PINK;
  return LIGHT_PINK;
}

export function waveBarHeights(activeLevel: number): number[] {
  return WAVEFORM_PATTERN.map((base: number) => waveBarHeight(waveBarFrac(base, activeLevel)));
}

export function waveBarColors(activeLevel: number): string[] {
  return WAVEFORM_PATTERN.map((base: number) => waveBarColor(waveBarFrac(base, activeLevel)));
}
