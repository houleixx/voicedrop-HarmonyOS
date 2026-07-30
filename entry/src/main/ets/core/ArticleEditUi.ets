export interface ArticleEditQueueState {
  id?: string;
  status?: string;
}

export class ArticleEditQueueItem {
  id: string;
  text: string;

  constructor(id: string, text: string) {
    this.id = id;
    this.text = text;
  }
}

export class ArticleEditEvent {
  type: string;
  id?: string;
  text?: string;
  message?: string;
  ok?: boolean;
  queue?: ArticleEditQueueState[];

  constructor(type: string = '', id?: string) {
    this.type = type;
    this.id = id;
  }
}

export class ArticleEditFeedback {
  text: string;
  ok: boolean;

  constructor(text: string, ok: boolean) {
    this.text = text;
    this.ok = ok;
  }
}

export class ArticleEditUi {
  static enqueue(queue: ArticleEditQueueItem[], id: string, text: string): ArticleEditQueueItem[] {
    const cleanId: string = id.trim();
    const cleanText: string = text.trim();
    if (cleanId.length === 0 || cleanText.length === 0) return queue.slice();
    if (queue.some((item: ArticleEditQueueItem): boolean => item.id === cleanId)) return queue.slice();
    return queue.concat(new ArticleEditQueueItem(cleanId, cleanText));
  }

  static reconcile(queue: ArticleEditQueueItem[], event: ArticleEditEvent): ArticleEditQueueItem[] {
    let result: ArticleEditQueueItem[] = queue.slice();
    if (event.type === 'updated' || event.type === 'error') {
      if (event.id && event.id.length > 0) {
        result = result.filter((item: ArticleEditQueueItem): boolean => item.id !== event.id);
      } else if (result.length > 0) {
        result = result.slice(1);
      }
    }
    const resolvedIds: Set<string> = new Set<string>();
    for (const item of event.queue ?? []) {
      if (item.id && (item.status === 'done' || item.status === 'error')) resolvedIds.add(item.id);
    }
    if (resolvedIds.size > 0) {
      result = result.filter((item: ArticleEditQueueItem): boolean => !resolvedIds.has(item.id));
    }
    return result;
  }

  static feedback(event: ArticleEditEvent): ArticleEditFeedback | undefined {
    if (event.type === 'reply') {
      const text: string = (event.text ?? event.message ?? '').trim();
      return text.length > 0 ? new ArticleEditFeedback(text, event.ok !== false) : undefined;
    }
    if (event.type === 'error') {
      const text: string = (event.message ?? event.text ?? '修改失败').trim();
      return new ArticleEditFeedback(text.length > 0 ? text : '修改失败', false);
    }
    return undefined;
  }
}
