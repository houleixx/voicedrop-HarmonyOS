import { ArticleBody } from './ArticleBody';

/** A non-editable article source selected from the article detail menu. */
export class BookWritingArticleSeed {
  title: string;
  body: string;

  constructor(title: string, body: string) {
    this.title = title.trim();
    this.body = ArticleBody.stripMarkers(body);
  }
}

/** Keeps the article-to-book request contract independent from the page UI. */
export class BookWritingSeed {
  static readonly MAX_LENGTH: number = 20000;

  static canSubmit(instruction: string, article?: BookWritingArticleSeed): boolean {
    return instruction.trim().length > 0 || article !== undefined;
  }

  static compose(instruction: string, article?: BookWritingArticleSeed): string {
    const request: string = instruction.trim();
    if (!article) return request.substring(0, BookWritingSeed.MAX_LENGTH);

    const prefix: string = request.length > 0 ? `写书要求：${request}\n\n` : '';
    const source: string = '以下这篇文章是种子素材，把它扩展成一本完整的书：\n\n' +
      `《${article.title}》\n\n${article.body}`;
    return (prefix + source).trim().substring(0, BookWritingSeed.MAX_LENGTH);
  }

  static preview(article: BookWritingArticleSeed, limit: number = 60): string {
    return article.body.replace(/\s+/g, ' ').trim().substring(0, limit);
  }
}
