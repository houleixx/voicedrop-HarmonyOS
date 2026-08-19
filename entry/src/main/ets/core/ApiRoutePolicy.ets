export class ApiRoutePolicy {
  static readonly CN_HOST: string = 'voicedrop.cn';
  static readonly CF_HOST: string = 'jianshuo.dev';
  static readonly HYSTERESIS_MS: number = 150;
  static readonly PROBE_MAX_AGE_MS: number = 30 * 60 * 1000;

  static normalizeHost(value: string): string {
    return value === ApiRoutePolicy.CF_HOST ? ApiRoutePolicy.CF_HOST : ApiRoutePolicy.CN_HOST;
  }

  static pick(incumbent: string, cnMs?: number, cfMs?: number): string {
    const current: string = ApiRoutePolicy.normalizeHost(incumbent);
    if (cnMs === undefined && cfMs === undefined) return current;
    if (cnMs !== undefined && cfMs === undefined) return ApiRoutePolicy.CN_HOST;
    if (cnMs === undefined && cfMs !== undefined) return ApiRoutePolicy.CF_HOST;
    const currentMs: number = current === ApiRoutePolicy.CN_HOST ? cnMs! : cfMs!;
    const challengerMs: number = current === ApiRoutePolicy.CN_HOST ? cfMs! : cnMs!;
    if (challengerMs + ApiRoutePolicy.HYSTERESIS_MS >= currentMs) return current;
    return current === ApiRoutePolicy.CN_HOST ? ApiRoutePolicy.CF_HOST : ApiRoutePolicy.CN_HOST;
  }

  static publicWebBase(host: string): string {
    return ApiRoutePolicy.normalizeHost(host) === ApiRoutePolicy.CN_HOST
      ? 'https://voicedrop.cn' : 'https://jianshuo.dev/voicedrop';
  }

  static shouldProbe(lastProbedAt: number, now: number,
    maxAge: number = ApiRoutePolicy.PROBE_MAX_AGE_MS): boolean {
    return lastProbedAt <= 0 || now - lastProbedAt > maxAge;
  }

  static isCurrentGeneration(activeGeneration: number, resultGeneration: number): boolean {
    return activeGeneration === resultGeneration;
  }
}
