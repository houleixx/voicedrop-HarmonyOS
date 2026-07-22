import { appPreferences } from '../data/AppPreferences';
import { PageHeader } from '../ui/PageHeader';

@Component
export struct BlockedAuthorsPage {
  onBack: () => void = () => {};
  @State private authors: string[] = [];

  aboutToAppear(): void { this.authors = appPreferences.blockedAuthors(); }

  build() {
    Column() {
      PageHeader({ title: '社区屏蔽管理', onBack: this.onBack })
      if (this.authors.length === 0) {
        Text('没有已屏蔽的作者').fontSize(16).fontColor('#888888').margin({ top: 80 })
      } else {
        List({ space: 10 }) {
          ForEach(this.authors, (author: string) => {
            ListItem() {
              Row() {
                Text(author).fontSize(17).layoutWeight(1)
                Button('解除屏蔽').fontSize(13).onClick(async () => {
                  await appPreferences.setAuthorBlocked(author, false);
                  this.authors = appPreferences.blockedAuthors();
                })
              }.padding(16).backgroundColor(Color.White).borderRadius(12)
            }
          }, (author: string) => author)
        }.layoutWeight(1).padding(16)
      }
    }.height('100%')
  }
}
