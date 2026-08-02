import { PhotoLoadIntent, PhotoLoadPolicy } from '../core/PhotoLoadPolicy';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';

type ArticlePhotoState = 'loading' | 'loaded' | 'making' | 'loadFailed' | 'failed';

class ArticlePhotoRequest {
  id: number;
  url: string;

  constructor(id: number, url: string) {
    this.id = id;
    this.url = url;
  }
}

@Component
export struct ArticlePhotoView {
  @Prop @Watch('onPhotoKeyChanged') photoKey: string = '';
  @Prop @Watch('onIntentChanged') intent: PhotoLoadIntent = 'original';
  loadPhoto: (ignoringLocalCache: boolean) => Promise<string> =
    (_: boolean): Promise<string> => Promise.resolve('');
  onLoaded: () => void = () => {};
  onLongPress: (event: GestureEvent) => void = (_: GestureEvent) => {};
  @State private state: ArticlePhotoState = 'loading';
  @State private activeRequest: ArticlePhotoRequest = new ArticlePhotoRequest(0, '');
  private nextRequestId: number = 0;
  private makingTimer: number = -1;
  private retryTimer: number = -1;
  private startedAt: number = 0;

  aboutToAppear(): void {
    this.beginLoad(false);
  }

  aboutToDisappear(): void {
    this.clearTimers();
    this.activeRequest = new ArticlePhotoRequest(++this.nextRequestId, '');
  }

  private onPhotoKeyChanged(): void {
    this.beginLoad(false);
  }

  private onIntentChanged(): void {
    this.beginLoad(false);
  }

  private beginLoad(forceRefresh: boolean): void {
    this.clearTimers();
    this.activeRequest = new ArticlePhotoRequest(++this.nextRequestId, '');
    this.startedAt = Date.now();
    this.state = PhotoLoadPolicy.startsMaking(this.intent) ? 'making' : 'loading';
    if (!PhotoLoadPolicy.shouldLoad(this.intent)) return;
    if (PhotoLoadPolicy.shouldPoll(this.intent) && this.state === 'loading') this.scheduleMakingState();
    this.fetchPhoto(forceRefresh).catch(() => {});
  }

  private async fetchPhoto(ignoringLocalCache: boolean): Promise<void> {
    const requestId: number = ++this.nextRequestId;
    this.activeRequest = new ArticlePhotoRequest(requestId, '');
    try {
      const source: string = await this.loadPhoto(ignoringLocalCache);
      if (requestId !== this.activeRequest.id) return;
      if (source.length === 0) {
        this.failed(requestId);
        return;
      }
      this.activeRequest = new ArticlePhotoRequest(requestId, source);
      this.loaded(requestId);
    } catch (_) {
      this.failed(requestId);
    }
  }

  private clearMakingTimer(): void {
    if (this.makingTimer < 0) return;
    clearTimeout(this.makingTimer);
    this.makingTimer = -1;
  }

  private clearRetryTimer(): void {
    if (this.retryTimer < 0) return;
    clearTimeout(this.retryTimer);
    this.retryTimer = -1;
  }

  private clearTimers(): void {
    this.clearMakingTimer();
    this.clearRetryTimer();
  }

  private loaded(requestId: number): void {
    if (requestId !== this.activeRequest.id) return;
    this.clearTimers();
    this.startedAt = 0;
    this.state = 'loaded';
    this.onLoaded();
  }

  private failed(requestId: number): void {
    if (requestId !== this.activeRequest.id) return;
    if (!PhotoLoadPolicy.shouldPoll(this.intent)) {
      this.clearTimers();
      this.state = 'loadFailed';
      return;
    }
    this.scheduleGeneratedRetry();
  }

  private elapsed(): number {
    return this.startedAt > 0 ? Math.max(0, Date.now() - this.startedAt) : 0;
  }

  private scheduleMakingState(): void {
    this.clearMakingTimer();
    const elapsed: number = this.elapsed();
    const nextState: ArticlePhotoState = PhotoLoadPolicy.generatedState(elapsed);
    if (nextState === 'failed') {
      this.state = 'failed';
      return;
    }
    if (nextState === 'making') {
      if (this.state !== 'loaded') this.state = 'making';
      return;
    }
    this.makingTimer = setTimeout(() => {
      this.makingTimer = -1;
      if (this.state === 'loading') this.state = 'making';
    }, PhotoLoadPolicy.MAKING_GRACE_MS - elapsed);
  }

  private scheduleGeneratedRetry(): void {
    this.clearRetryTimer();
    const elapsed: number = this.elapsed();
    const nextState: ArticlePhotoState = PhotoLoadPolicy.generatedState(elapsed);
    if (nextState === 'failed') {
      this.clearMakingTimer();
      this.state = 'failed';
      return;
    }
    if (nextState === 'making') this.state = 'making';
    this.retryTimer = setTimeout(() => {
      this.retryTimer = -1;
      this.retryGenerated();
    }, PhotoLoadPolicy.generatedRetryDelay(elapsed));
  }

  private retryGenerated(): void {
    const nextState: ArticlePhotoState = PhotoLoadPolicy.generatedState(this.elapsed());
    if (nextState === 'failed') {
      this.clearMakingTimer();
      this.state = 'failed';
      return;
    }
    this.state = nextState;
    if (nextState === 'loading') this.scheduleMakingState();
    this.fetchPhoto(true).catch(() => {});
  }

  private retry(): void {
    this.beginLoad(true);
  }

  @Builder
  private placeholder(title: string, subtitle: string = '') {
    Column({ space: 10 }) {
      Text('▧').fontSize(30).fontColor('#C98A2E')
      Text(title).fontSize(13).fontWeight(FontWeight.Bold).fontColor('#8A7B60')
      if (subtitle.length > 0) Text(subtitle).fontSize(11).fontColor('#B4A98F')
    }
      .justifyContent(FlexAlign.Center)
      .width('100%')
      .height(240)
      .backgroundColor('#F3EEE4')
      .borderRadius(12)
  }

  build() {
    Stack() {
      if (this.state === 'loaded' && this.activeRequest.url.length > 0) {
        ForEach([this.activeRequest], (request: ArticlePhotoRequest) => {
          Image(request.url)
            .width('100%')
            .objectFit(ImageFit.Contain)
            .borderRadius(12)
            .draggable(false)
            .opacity(1)
            .onError(() => this.failed(request.id))
            .priorityGesture(LongPressGesture().onAction((event: GestureEvent) => this.onLongPress(event)))
        }, (request: ArticlePhotoRequest) => `${request.id}`)
      }
      if (this.state === 'loading') {
        Column() {
          LoadingProgress().width(34).height(34).color(Theme.ACCENT_STRONG)
        }
          .justifyContent(FlexAlign.Center)
          .width('100%')
          .height(240)
          .backgroundColor('#F3EEE4')
          .borderRadius(12)
      } else if (this.state === 'making') {
        this.placeholder('正在制作中', '约 1 分钟完成')
      } else if (this.state === 'loadFailed' || this.state === 'failed') {
        Column({ space: 10 }) {
          Text(this.state === 'loadFailed' ? '图片加载失败' : '暂时无法显示')
            .fontSize(13).fontWeight(FontWeight.Bold).fontColor('#8A7B60')
          Button('重试').fontSize(12).fontColor('#C0682E').backgroundColor(Color.Transparent)
            .onClick(() => this.retry())
        }
          .justifyContent(FlexAlign.Center)
          .width('100%')
          .height(240)
          .backgroundColor('#F4F1EB')
          .borderRadius(12)
      }
    }
      .width('100%')
      .margin({ top: 5, bottom: 9 })
  }
}
