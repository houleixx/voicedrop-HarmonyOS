import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { http } from '@kit.NetworkKit';
import { ApiRoutePolicy } from './ApiRoutePolicy';

export class ApiRouteProbeResult {
  host: string;
  switched: boolean;
  cnMs?: number;
  cfMs?: number;

  constructor(host: string, switched: boolean, cnMs?: number, cfMs?: number) {
    this.host = host;
    this.switched = switched;
    this.cnMs = cnMs;
    this.cfMs = cfMs;
  }
}

/**
 * 国内/海外 HTTP 优选线路的唯一状态入口。
 *
 * 调用方只读取当前 host/公开网页前缀，并在主界面初始化或回前台时通知本模块；
 * 并发 HEAD、6 秒超时、150ms 迟滞、持久化和陈旧探测隔离都封装在内部。
 */
export class ApiRoute {
  private static readonly STORE_NAME: string = 'voicedrop.api-route';
  private static readonly HOST_KEY: string = 'host';
  private static readonly PROBED_AT_KEY: string = 'probedAt';
  private store?: preferences.Preferences;
  private selectedHost: string = ApiRoutePolicy.CN_HOST;
  private lastProbedAt: number = 0;
  private initialized: boolean = false;
  private generation: number = 0;
  private probing: boolean = false;
  private activeRequests: http.HttpRequest[] = [];

  host(): string { return this.selectedHost; }

  publicWebBase(): string { return ApiRoutePolicy.publicWebBase(this.selectedHost); }

  /**
   * 恢复上次选线。主界面传 true：每次冷启动都异步强制测速；
   * 分享扩展传 false：生命周期短，只复用主界面的持久化结果。
   */
  async initialize(context: common.Context, probeOnStart: boolean = true): Promise<void> {
    if (this.initialized) {
      if (probeOnStart) this.runProbe().catch(() => {});
      return;
    }
    try {
      this.store = await preferences.getPreferences(context, { name: ApiRoute.STORE_NAME });
      this.selectedHost = ApiRoutePolicy.normalizeHost(
        String(this.store.getSync(ApiRoute.HOST_KEY, ApiRoutePolicy.CN_HOST) ?? ApiRoutePolicy.CN_HOST));
      this.lastProbedAt = Number(this.store.getSync(ApiRoute.PROBED_AT_KEY, 0) ?? 0);
    } catch (_) {
      // 偏好存储不可用不能拖垮 App；本进程继续使用默认线路并完成测速。
      this.store = undefined;
      this.selectedHost = ApiRoutePolicy.CN_HOST;
      this.lastProbedAt = 0;
    }
    this.initialized = true;
    if (probeOnStart) this.runProbe().catch(() => {});
  }

  /** 回前台入口：距上次完成探测不足 30 分钟或已有探测在跑时直接返回。 */
  async probeIfDue(now: number = Date.now()): Promise<ApiRouteProbeResult | undefined> {
    if (!this.initialized || this.probing ||
      !ApiRoutePolicy.shouldProbe(this.lastProbedAt, now)) return undefined;
    return this.runProbe();
  }

  private async runProbe(): Promise<ApiRouteProbeResult | undefined> {
    const probeGeneration: number = ++this.generation;
    this.cancelRequestsOnly();
    this.probing = true;
    const cnRequest: http.HttpRequest = http.createHttp();
    const cfRequest: http.HttpRequest = http.createHttp();
    this.activeRequests = [cnRequest, cfRequest];
    const incumbent: string = this.selectedHost;
    try {
      const durations: (number | undefined)[] = await Promise.all([
        this.measure(cnRequest, 'https://voicedrop.cn/'),
        this.measure(cfRequest, 'https://jianshuo.dev/voicedrop/')
      ]);
      if (!ApiRoutePolicy.isCurrentGeneration(this.generation, probeGeneration)) return undefined;
      const cnMs: number | undefined = durations[0];
      const cfMs: number | undefined = durations[1];
      const winner: string = ApiRoutePolicy.pick(incumbent, cnMs, cfMs);
      const completedAt: number = Date.now();
      this.selectedHost = winner;
      this.lastProbedAt = completedAt;
      if (this.store) {
        try {
          this.store.putSync(ApiRoute.HOST_KEY, winner);
          this.store.putSync(ApiRoute.PROBED_AT_KEY, completedAt);
          await this.store.flush();
        } catch (_) {}
      }
      return new ApiRouteProbeResult(winner, winner !== incumbent, cnMs, cfMs);
    } finally {
      cnRequest.destroy();
      cfRequest.destroy();
      if (ApiRoutePolicy.isCurrentGeneration(this.generation, probeGeneration)) {
        this.activeRequests = [];
        this.probing = false;
      }
    }
  }

  private async measure(request: http.HttpRequest, url: string): Promise<number | undefined> {
    const startedAt: number = Date.now();
    let timer: number = -1;
    const timeout: Promise<number | undefined> = new Promise<number | undefined>((resolve) => {
      timer = setTimeout(() => {
        try { request.destroy(); } catch (_) {}
        resolve(undefined);
      }, 6000);
    });
    try {
      return await Promise.race([this.performMeasure(request, url, startedAt), timeout]);
    } finally {
      if (timer >= 0) clearTimeout(timer);
    }
  }

  private async performMeasure(request: http.HttpRequest, url: string,
    startedAt: number): Promise<number | undefined> {
    try {
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.HEAD,
        header: {
          'Accept': '*/*',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'X-VD-Platform': 'harmonyos'
        },
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 6000,
        readTimeout: 6000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) return undefined;
      return Math.max(0, Date.now() - startedAt);
    } catch (_) {
      return undefined;
    }
  }

  private cancelRequestsOnly(): void {
    for (const request of this.activeRequests) {
      try { request.destroy(); } catch (_) {}
    }
    this.activeRequests = [];
  }
}

export const apiRoute: ApiRoute = new ApiRoute();
