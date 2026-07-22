@Component
export struct HomePage {
  @Link tab: number;
  @BuilderParam libraryContent: () => void = this.empty;
  @BuilderParam communityContent: () => void = this.empty;

  @Builder
  private empty() {}

  build() {
    if (this.tab === 0) this.libraryContent()
    else this.communityContent()
  }
}
