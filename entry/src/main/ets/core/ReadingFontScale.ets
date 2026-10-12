export class ReadingFontScale {
  static readonly VALUES: number[] = [0.9, 1, 1.15, 1.3, 1.5];
  static readonly LABELS: string[] = ['小', '标准', '大', '特大', '超大'];

  static normalize(value: number): number {
    return ReadingFontScale.VALUES.includes(value) ? value : 1;
  }

  static percent(value: number): number {
    return Math.round(ReadingFontScale.normalize(value) * 100);
  }

  static label(value: number): string {
    return ReadingFontScale.LABELS[ReadingFontScale.VALUES.indexOf(ReadingFontScale.normalize(value))];
  }

  static forCommunity(active: boolean, prompt: boolean, value: number): number {
    return active && !prompt ? ReadingFontScale.normalize(value) : 1;
  }
}
