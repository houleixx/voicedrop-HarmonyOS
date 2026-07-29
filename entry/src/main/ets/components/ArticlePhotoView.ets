import { PhotoLoadIntent, PhotoLoadPolicy } from '../core/PhotoLoadPolicy';

type ArticlePhotoState = 'loading' | 'loaded' | 'grace' | 'making' | 'loadFailed' | 'failed';

@Component
export struct ArticlePhotoView {
  @Prop @Watch('onUrlChanged') url: string = '';
  @Prop @Watch('onIntentChanged') intent: PhotoLoadIntent = 'original';
  onLoaded: () => void = () => {};
  @State private state: ArticlePhotoState = 'loading';
  @State private attempt: number = 0;
  private timer: number = -1;
  private deadline: number = 0;

  aboutToDisappear(): void {
    this.clearTimer();
  }

  private onUrlChanged(): void {
    this.clearTimer();
    this.deadline = 0;
    this.attempt = 0;
    this.state = 'loading';
  }

  private onIntentChanged(): void {
    if (this.intent !== 'generated') return;
    this.clearTimer();
    this.deadline = Date.now() + 300000;
    this.state = 'grace';
    this.attempt += 1;
    this.timer = setTimeout(() => {
      this.timer = -1;
      this.retryGenerated();
    }, 900);
  }

  private requestUrl(): string {
    if (this.attempt === 0) return this.url;
    return `${this.url}${this.url.includes('?') ? '&' : '?'}v=${Date.now()}-${this.attempt}`;
  }

  private clearTimer(): void {
    if (this.timer < 0) return;
    clearTimeout(this.timer);
    this.timer = -1;
  }

  private loaded(): void {
    this.clearTimer();
    this.deadline = 0;
    this.state = 'loaded';
    this.onLoaded();
  }

  private failed(): void {
    if (!PhotoLoadPolicy.shouldPoll(this.intent)) {
      this.clearTimer();
      this.state = 'loadFailed';
      return;
    }
    if (this.deadline === 0) {
      this.deadline = Date.now() + 300000;
      this.state = 'grace';
      this.clearTimer();
      this.timer = setTimeout(() => {
        this.timer = -1;
        this.retryGenerated();
      }, 900);
      return;
    }
    this.scheduleGeneratedRetry();
  }

  private scheduleGeneratedRetry(): void {
    this.clearTimer();
    if (Date.now() >= this.deadline) {
      this.state = 'failed';
      return;
    }
    this.state = 'making';
    this.timer = setTimeout(() => {
      this.timer = -1;
      this.retryGenerated();
    }, 3000);
  }

  private retryGenerated(): void {
    if (Date.now() >= this.deadline) {
      this.state = 'failed';
      return;
    }
    this.state = 'making';
    this.attempt += 1;
  }

  private retry(): void {
    this.clearTimer();
    this.deadline = 0;
    this.state = 'loading';
    this.attempt += 1;
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
      if (this.state === 'loading' || this.state === 'loaded' ||
          this.state === 'grace' || this.state === 'making') {
        Image(this.requestUrl())
          .width('100%')
          .objectFit(ImageFit.Contain)
          .borderRadius(12)
          .opacity(this.state === 'loaded' || this.state === 'loading' ? 1 : 0)
          .onComplete(() => this.loaded())
          .onError(() => this.failed())
      }
      if (this.state === 'grace') {
        this.placeholder('', '')
      } else if (this.state === 'loading') {
        Column() {
          LoadingProgress().width(34).height(34).color('#C98A2E')
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
    }.width('100%').margin({ top: 10, bottom: 10 })
  }
}
