import { ArticleBlock, ArticleBody } from '../core/ArticleBody';
import { ArticleDoc, MinedArticle } from '../model/Models';
import { PageHeader } from '../ui/PageHeader';

@Component
export struct SharedArticlePage {
  onBack: () => void = () => {};
  @Prop article?: ArticleDoc = undefined;
  @Link selectedIndex: number;

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
      Text(block.value).fontSize(17).lineHeight(30).fontColor('#252525').width('100%').copyOption(CopyOptions.LocalDevice)
    }
  }

  build() {
    Column() {
      PageHeader({ title: '分享的文章', onBack: this.onBack })
      if (!this.article || this.article.articles.length === 0) {
        Text('这篇分享已不可用').fontSize(16).fontColor('#888888').margin({ top: 80 })
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
            Text(this.article!.articles[this.selectedIndex].title).fontSize(28).fontWeight(FontWeight.Bold).width('100%')
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
