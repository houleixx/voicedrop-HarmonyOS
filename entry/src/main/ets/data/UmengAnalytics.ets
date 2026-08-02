import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { init, InternalPlugin, preInit } from '@umeng/analytics';

export class UmengAnalytics {
  private preInitialized: boolean = false;
  private initialized: boolean = false;
  private initializing: boolean = false;

  preInitialize(context: common.ApplicationContext): void {
    if (this.preInitialized) return;
    try {
      preInit({
        context: context,
        plugins: [new InternalPlugin()]
      });
      this.preInitialized = true;
    } catch (error) {
      hilog.error(0x0000, 'VoiceDrop', 'Umeng analytics preInit failed: %{public}s', JSON.stringify(error));
    }
  }

  async initializeAfterPrivacyConsent(): Promise<void> {
    if (this.initialized || this.initializing) return;
    if (!this.preInitialized) {
      hilog.warn(0x0000, 'VoiceDrop', 'Umeng analytics init skipped because preInit did not complete');
      return;
    }
    this.initializing = true;
    try {
      await init();
      this.initialized = true;
    } catch (error) {
      hilog.error(0x0000, 'VoiceDrop', 'Umeng analytics init failed: %{public}s', JSON.stringify(error));
    } finally {
      this.initializing = false;
    }
  }
}

export const umengAnalytics: UmengAnalytics = new UmengAnalytics();
