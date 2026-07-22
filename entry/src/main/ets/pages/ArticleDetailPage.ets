@Component
export struct ArticleDetailPage {
  @BuilderParam content: () => void = this.empty;

  @Builder
  private empty() {}

  build() { this.content() }
}
