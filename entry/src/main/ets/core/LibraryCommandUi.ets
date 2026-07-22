export enum LibraryCommandTone {
  Hidden,
  Normal,
  Active,
  Error
}

export enum LibraryCommandGestureAction {
  None,
  Record,
  Send,
  Cancel
}

export class LibraryCommandFeedback {
  text: string;
  tone: LibraryCommandTone;

  constructor(text: string = '', tone: LibraryCommandTone = LibraryCommandTone.Hidden) {
    this.text = text;
    this.tone = tone;
  }

  visible(): boolean { return this.text.length > 0 && this.tone !== LibraryCommandTone.Hidden; }
}

export class LibraryCommandEvent {
  type: string;
  state?: string;
  text?: string;
  message?: string;

  constructor(type: string, state?: string, text?: string, message?: string) {
    this.type = type;
    this.state = state;
    this.text = text;
    this.message = message;
  }
}

export class LibraryCommandTarget {
  stem: string;
  title: string;
  uploading: boolean;

  constructor(stem: string, title: string, uploading: boolean) {
    this.stem = stem;
    this.title = title;
    this.uploading = uploading;
  }
}

export class LibraryCommandTargetRef {
  number: number;
  stem: string;
  title: string;

  constructor(number: number, stem: string, title: string) {
    this.number = number;
    this.stem = stem;
    this.title = title;
  }
}

export class LibraryCommandUi {
  static isQuietMessage(message: string): boolean {
    const value: string = message.trim();
    if (value.length === 0) return false;
    return value.includes('已连接图库指令') ||
      value.includes('已连接到图库指令') ||
      value.includes('正在恢复图库指令') ||
      value.includes('正在执行图库指令') ||
      value.includes('图库指令连接断开') ||
      value.includes('图库指令已完成');
  }

  static feedbackForEvent(event: LibraryCommandEvent): LibraryCommandFeedback {
    if (event.type === 'status') {
      return event.state === 'working'
        ? new LibraryCommandFeedback('正在执行图库指令…', LibraryCommandTone.Active)
        : new LibraryCommandFeedback();
    }
    if (event.type === 'updated') {
      return new LibraryCommandFeedback('图库指令已完成', LibraryCommandTone.Normal);
    }
    if (event.type === 'reply') {
      const text: string = (event.text ?? '').trim();
      if (LibraryCommandUi.isQuietMessage(text)) return new LibraryCommandFeedback();
      return new LibraryCommandFeedback(text.length > 0 ? text : '指令已完成', LibraryCommandTone.Normal);
    }
    if (event.type === 'error') {
      const text: string = (event.message ?? '').trim();
      return new LibraryCommandFeedback(text.length > 0 ? text : '图库指令执行失败', LibraryCommandTone.Error);
    }
    return new LibraryCommandFeedback();
  }

  static recordButtonLabel(talking: boolean, canceled: boolean): string {
    if (!talking) return '轻点录音 · 长按说话';
    return canceled ? '上滑取消 · 松开放弃' : '松开发送 · 上滑取消';
  }

  static dictationFeedback(transcript: string, canceled: boolean): LibraryCommandFeedback {
    if (canceled) return new LibraryCommandFeedback('松手取消图库指令', LibraryCommandTone.Error);
    const text: string = transcript.trim();
    return new LibraryCommandFeedback(text.length > 0 ? text : '在听…', LibraryCommandTone.Active);
  }

  static gestureAction(longPressed: boolean, canceled: boolean, interrupted: boolean): LibraryCommandGestureAction {
    if (longPressed) return canceled || interrupted ? LibraryCommandGestureAction.Cancel : LibraryCommandGestureAction.Send;
    return interrupted ? LibraryCommandGestureAction.None : LibraryCommandGestureAction.Record;
  }

  static commandRefs(targets: LibraryCommandTarget[]): LibraryCommandTargetRef[] {
    const refs: LibraryCommandTargetRef[] = [];
    for (const target of targets) {
      if (target.uploading) continue;
      refs.push(new LibraryCommandTargetRef(refs.length + 1, target.stem, target.title));
    }
    return refs;
  }
}
