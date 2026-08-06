import { appPreferences } from '../data/AppPreferences';
import { PageHeader } from '../ui/PageHeader';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';

@Component
export struct BlockedAuthorsPage {
  onBack: () => void = () => {};
  onUnblocked: (count: number) => void = (_count: number) => {};
  @State private authors: string[] = [];

  aboutToAppear(): void { this.authors = appPreferences.blockedAuthors(); }

  build() {
    Column() {
      PageHeader({ title: '社区屏蔽管理', onBack: this.onBack })
      if (this.authors.length === 0) {
        Column() {
          Text('没有已屏蔽的作者')
            .fontSize(16)
            .fontColor(Theme.SECONDARY)
            .textAlign(TextAlign.Center)
            .width('100%')
        }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: 16, right: 16, top: 16 })
          .justifyContent(FlexAlign.Start)
      } else {
        List({ space: 10 }) {
          ForEach(this.authors, (author: string) => {
            ListItem() {
              Row() {
                Text(author).fontSize(17).layoutWeight(1)
                Button('解除屏蔽').fontSize(13).fontColor(Theme.ACCENT)
                  .backgroundColor(Theme.ACCENT_SOFT).onClick(async () => {
                  await appPreferences.setAuthorBlocked(author, false);
                  this.authors = appPreferences.blockedAuthors();
                  this.onUnblocked(this.authors.length);
                })
              }.padding(16).backgroundColor(Color.White).borderRadius(12)
            }
          }, (author: string) => author)
        }
          .layoutWeight(1)
          .padding({ left: 16, right: 16, top: 6, bottom: 16 })
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      }
    }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
  }
}
