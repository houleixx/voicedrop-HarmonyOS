export class ArticleInsertImage {
  key: string;
  constructor(key: string) { this.key = key; }
}

export class ArticlePhotoInsert {
  static imagesForKeys(keys: string[]): ArticleInsertImage[] {
    return keys.filter((key: string) => key.trim().length > 0)
      .map((key: string) => new ArticleInsertImage(key));
  }

  static instructionForKeys(keys: string[]): string {
    const valid: string[] = keys.filter((key: string) => key.trim().length > 0);
    if (valid.length === 0) return '';
    const markers: string = valid.map((key: string) => `[[photo:${key}]]`).join('、');
    const countWord: string = valid.length === 1 ? '这张照片' : `这${valid.length}张照片`;
    const pronoun: string = valid.length === 1 ? '它' : '每一张都';
    return `我刚拍了${countWord}，请把${pronoun}插入文章里最合适的位置。` +
      `每张照片用它自己的标记（原样写进正文，放在和场景最相符的段落附近）：${markers}。` +
      '所有照片必须全部插入，不能遗漏。';
  }
}
