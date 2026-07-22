@Component
export struct CommunityDetailPage {
  @BuilderParam content: () => void = this.empty;

  @Builder
  private empty() {}

  build() { this.content() }
}
