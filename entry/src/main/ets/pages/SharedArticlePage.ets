import { ReadingFontSheet } from '../ui/ReadingFont';
import { RemixIconGlyph as RI } from '../ui/RemixIcon';
import { ArticleBlock, ArticleBody } from '../core/ArticleBody';
import { ArticleDoc, MinedArticle } from '../model/Models';
import { PageHeader } from '../ui/PageHeader';
import { AppLocale } from '../core/AppLocale';
import { AiGeneratedLabel } from '../ui/AiGeneratedLabel';

@Component
export struct SharedArticlePage {
  private readingFontDialog: CustomDialogController = new CustomDialogController({
    builder: ReadingFontSheet(),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Bottom,
    width: '100%',
    maskColor: '#66000000',
    openAnimation: { duration: 240, curve: Curve.EaseOut },
    closeAnimation: { duration: 180, curve: Curve.EaseIn }
  });

  onBack: () => void = () => {};
  @Prop article?: ArticleDoc = undefined;
  @Link selectedIndex: number;
  @StorageLink('readingFontScale') private readingFontScale: number = 1;

  aboutToDisappear(): void {
    this.readingFontDialog.close();
  }

  private photoUrl(token: string): string {
    if (!this.article) return '';
    const resolved: string | undefined = ArticleBody.resolvePhotoKey(token, this.article.photos);
    if (!resolved) return '';
    const owner: string = (this.article.owner ?? '').replace(/\/+$/, '');
    const key: string = owner.length > 0 && !resolved.startsWith('users/') ? `${owner}/${resolved}` : resolved;
    return ArticleBody.photoUrl(key);
  }

  @Builder
  private articleBlock(block: ArticleBlock) {
    if (block.kind === 'photo') {
      if (this.photoUrl(block.value).length > 0) {
        Image(this.photoUrl(block.value)).width('100%').objectFit(ImageFit.Contain).borderRadius(12).margin({ top: 10, bottom: 10 })
      }
    } else {
      Text(block.value).fontSize(17 * this.readingFontScale).lineHeight(30 * this.readingFontScale).fontColor('#252525').width('100%').copyOption(CopyOptions.LocalDevice)
    }
  }

  build() {
    Column() {
      PageHeader({ title: AppLocale.text('分享的文章'), onBack: this.onBack,
        actionGlyph: RI.FONT_SIZE, actionLabel: AppLocale.text('字号'), actionFilled: false,
        onAction: (): void => { this.readingFontDialog.open(); } })
      if (!this.article || this.article.articles.length === 0) {
        Text(AppLocale.text('这篇分享已不可用')).fontSize(16).fontColor('#888888').margin({ top: 80 })
      } else {
        Scroll() {
          Column({ space: 12 }) {
            if (this.article!.articles.length > 1) {
              Scroll() {
                Row({ space: 8 }) {
                  ForEach(this.article!.articles, (item: MinedArticle, index: number) =>
                    Button(item.title).fontSize(13).fontColor(index === this.selectedIndex ? '#D92D20' : '#666666')
                      .backgroundColor(index === this.selectedIndex ? '#FFE6DF' : '#EFEFED')
                      .onClick(() => this.selectedIndex = index))
                }
              }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
            }
            Text(this.article!.articles[this.selectedIndex].title).fontSize(28 * this.readingFontScale).fontWeight(FontWeight.Bold).width('100%')
            Row() {
              Blank()
              AiGeneratedLabel()
            }.width('100%')
            ForEach(ArticleBody.blocks(this.article!.articles[this.selectedIndex].body),
              (block: ArticleBlock) => this.articleBlock(block))
          }.padding({ left: 16, right: 16, top: 6, bottom: 40 }).alignItems(HorizontalAlign.Start).width('100%')
        }
          .layoutWeight(1)
          .width('100%')
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      }
    }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
  }
}
