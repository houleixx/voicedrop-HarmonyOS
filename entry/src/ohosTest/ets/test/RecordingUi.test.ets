import { describe, expect, it } from '@ohos/hypium';
import {
  formatRecordingTime,
  normalizeAmplitude,
  waveBarFrac,
  waveBarHeight,
  waveBarColor,
  waveBarHeights,
  waveBarColors,
  WAVEFORM_PATTERN
} from '../../../main/ets/core/RecordingUi';

export default function recordingUiTest() {
  describe('RecordingUi', () => {

    describe('formatRecordingTime', () => {
      it('formatsZeroAs00Colon00', 0, () => {
        expect(formatRecordingTime(0)).assertEqual('00:00');
      });

      it('formatsFiveSeconds', 0, () => {
        expect(formatRecordingTime(5)).assertEqual('00:05');
      });

      it('formatsOneMinute', 0, () => {
        expect(formatRecordingTime(60)).assertEqual('01:00');
      });

      it('formatsOneMinuteFiveSeconds', 0, () => {
        expect(formatRecordingTime(65)).assertEqual('01:05');
      });

      it('formatsTenMinutes', 0, () => {
        expect(formatRecordingTime(600)).assertEqual('10:00');
      });

      it('formatsFiftyNineSeconds', 0, () => {
        expect(formatRecordingTime(59)).assertEqual('00:59');
      });

      it('clampsNegativeAndFloorsFractions', 0, () => {
        expect(formatRecordingTime(-4)).assertEqual('00:00');
        expect(formatRecordingTime(5.9)).assertEqual('00:05');
      });
    });

    describe('normalizeAmplitude', () => {
      it('returnsZeroForZeroPeak', 0, () => {
        expect(normalizeAmplitude(0)).assertEqual(0);
      });

      it('clampsTo1ForPeakAbovePcmRange', 0, () => {
        expect(normalizeAmplitude(65535)).assertEqual(1);
      });

      it('removesMicrophoneNoiseFloor', 0, () => {
        expect(normalizeAmplitude(491)).assertEqual(0);
      });

      it('normalizesMidRangeWithResponsiveCurve', 0, () => {
        const result: number = normalizeAmplitude(16384);
        expect(result > 0 && result < 1).assertEqual(true);
      });

      it('growsWithAmplitude', 0, () => {
        expect(normalizeAmplitude(16384) > normalizeAmplitude(3277)).assertEqual(true);
      });
    });

    describe('waveBarFrac', () => {
      it('keepsSixPercentOfBaseAtSilence', 0, () => {
        const result: number = waveBarFrac(0.5, 0);
        expect(result).assertEqual(0.03);
      });

      it('capsAtBaseAtMaxLevel', 0, () => {
        const result: number = waveBarFrac(0.5, 1);
        expect(result).assertEqual(0.5);
      });

      it('scalesLinearlyBetween', 0, () => {
        const mid: number = waveBarFrac(0.5, 0.5);
        const silence: number = waveBarFrac(0.5, 0);
        const max: number = waveBarFrac(0.5, 1);
        expect(mid > silence && mid < max).assertEqual(true);
      });
    });

    describe('waveBarHeight', () => {
      it('returnsMinimum6ForZeroFrac', 0, () => {
        expect(waveBarHeight(0)).assertEqual(6);
      });

      it('returnsMax46ForFullFrac', 0, () => {
        expect(waveBarHeight(1)).assertEqual(46);
      });

      it('returnsIntermediateValue', 0, () => {
        const h: number = waveBarHeight(0.5);
        expect(h).assertEqual(23);
      });
    });

    describe('waveBarColor', () => {
      it('returnsRedForHighFrac', 0, () => {
        expect(waveBarColor(0.7)).assertEqual('#E5392E');
      });

      it('returnsWarmPinkForMidFrac', 0, () => {
        expect(waveBarColor(0.4)).assertEqual('#EBA89F');
      });

      it('returnsLightPinkForLowFrac', 0, () => {
        expect(waveBarColor(0.2)).assertEqual('#E5C8C3');
      });

      it('returnsRedAtExactBoundary06', 0, () => {
        expect(waveBarColor(0.61)).assertEqual('#E5392E');
      });

      it('returnsWarmPinkAtExactBoundary03', 0, () => {
        expect(waveBarColor(0.31)).assertEqual('#EBA89F');
      });
    });

    describe('waveBarHeights', () => {
      it('returns13BarsAtSilence', 0, () => {
        const bars: number[] = waveBarHeights(0);
        expect(bars.length).assertEqual(13);
        bars.forEach((h: number) => {
          expect(h >= 6).assertEqual(true);
        });
      });

      it('returns13BarsAtMaxLevel', 0, () => {
        const bars: number[] = waveBarHeights(1);
        expect(bars.length).assertEqual(13);
        bars.forEach((h: number) => {
          expect(h <= 46).assertEqual(true);
        });
      });

      it('barsGrowWithActiveLevel', 0, () => {
        const silent: number[] = waveBarHeights(0);
        const loud: number[] = waveBarHeights(1);
        for (let i: number = 0; i < 13; i++) {
          expect(loud[i] >= silent[i]).assertEqual(true);
        }
      });
    });

    describe('waveBarColors', () => {
      it('returns13ColorsAtSilence', 0, () => {
        const colors: string[] = waveBarColors(0);
        expect(colors.length).assertEqual(13);
      });

      it('highBaseBarsAreRedAtMaxLevel', 0, () => {
        const colors: string[] = waveBarColors(1);
        const highBase: number = WAVEFORM_PATTERN.indexOf(0.95);
        expect(colors[highBase]).assertEqual('#E5392E');
      });
    });

    describe('WAVEFORM_PATTERN', () => {
      it('has13Entries', 0, () => {
        expect(WAVEFORM_PATTERN.length).assertEqual(13);
      });

      it('allValuesBetween0And1', 0, () => {
        WAVEFORM_PATTERN.forEach((v: number) => {
          expect(v > 0 && v <= 1).assertEqual(true);
        });
      });
    });

  });
}
