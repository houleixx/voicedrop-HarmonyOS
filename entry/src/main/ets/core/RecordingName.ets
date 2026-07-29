export interface ParsedRecordingName {
  sessionTs: string;
  month: number;
  day: number;
  hhmm: string;
  duration: string;
  weekday: string;
  period: string;
  place: string;
}

export class RecordingName {
  static timestamp(value: Date): string {
    const date: string = `${value.getFullYear()}-${RecordingName.two(value.getMonth() + 1)}-${RecordingName.two(value.getDate())}`;
    const time: string = `${RecordingName.two(value.getHours())}${RecordingName.two(value.getMinutes())}${RecordingName.two(value.getSeconds())}`;
    return `${date}-${time}`;
  }

  static isRecordingFile(name: string): boolean {
    return name.startsWith('VoiceDrop-') && name.endsWith('.m4a');
  }

  static stem(name: string): string {
    return name.endsWith('.m4a') ? name.substring(0, name.length - 4) : name;
  }

  static photoKey(sessionTimestamp: string, offsetSeconds: number, randomTag: string = ''): string {
    const generated: string = Math.random().toString(36).substring(2, 5).padEnd(3, '0');
    const tag: string = (randomTag.length > 0 ? randomTag : generated)
      .toLowerCase().replace(/[^0-9a-z]/g, '').substring(0, 3).padEnd(3, '0');
    return `photos/${sessionTimestamp}/${Math.max(0, Math.floor(offsetSeconds))}-${tag}.jpg`;
  }

  static parse(name: string): ParsedRecordingName | undefined {
    const stem: string = RecordingName.stem(name);
    const match: RegExpMatchArray | null = stem.match(/^VoiceDrop-(\d{4}-\d{2}-\d{2}-\d{6})-(\d+m\d+s)-([A-Za-z]+)-([A-Za-z]+)(?:-(.+))?$/);
    if (!match) {
      return undefined;
    }
    return {
      sessionTs: match[1], month: Number(match[1].substring(5, 7)), day: Number(match[1].substring(8, 10)),
      hhmm: `${match[1].substring(11, 13)}:${match[1].substring(13, 15)}`,
      duration: match[2], weekday: match[3], period: match[4],
      place: match[5] ? match[5].split('-').pop() ?? '' : ''
    };
  }

  static create(startedAt: Date, durationSeconds: number, place: string = ''): string {
    const timestamp: string = RecordingName.timestamp(startedAt);
    const weekdays: string[] = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const totalSeconds: number = Math.max(0, Math.round(durationSeconds));
    const duration: string = `${Math.floor(totalSeconds / 60)}m${RecordingName.two(totalSeconds % 60)}s`;
    const suffix: string = place.trim().length > 0 ? `-${place.trim().replace(/[/\\:?*"<>|]/g, '')}` : '';
    return `VoiceDrop-${timestamp}-${duration}-${weekdays[startedAt.getDay()]}-${RecordingName.period(startedAt.getHours())}${suffix}.m4a`;
  }

  static rowTitle(name: string): string {
    const parsed: ParsedRecordingName | undefined = RecordingName.parse(name);
    if (!parsed) return RecordingName.stem(name);
    const weekdayMap: Record<string, string> = {
      'Sun': '周日', 'Mon': '周一', 'Tue': '周二', 'Wed': '周三', 'Thu': '周四', 'Fri': '周五', 'Sat': '周六'
    };
    const periodMap: Record<string, string> = {
      'EarlyMorning': '清晨', 'Morning': '上午', 'Noon': '中午', 'Afternoon': '下午',
      'Evening': '傍晚', 'Night': '晚上', 'LateNight': '深夜'
    };
    const base: string = `${weekdayMap[parsed.weekday] ?? parsed.weekday}·${periodMap[parsed.period] ?? parsed.period}`;
    return parsed.place.length > 0 ? `${base} · ${parsed.place}` : base;
  }

  private static two(value: number): string { return value.toString().padStart(2, '0'); }
  private static period(hour: number): string {
    if (hour < 5) return 'LateNight';
    if (hour < 9) return 'EarlyMorning';
    if (hour < 12) return 'Morning';
    if (hour < 14) return 'Noon';
    if (hour < 18) return 'Afternoon';
    if (hour < 20) return 'Evening';
    if (hour < 23) return 'Night';
    return 'LateNight';
  }
}
