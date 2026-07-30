import { Recording } from '../model/Models';

export class RecordingListUi {
  static readonly deleteMessage: string = '音频和已挖出的文章都会从云端删除，不可恢复。';

  static rowRenderKey(recording: Recording): string {
    return [
      recording.name,
      recording.saving ? 'saving' : '',
      recording.uploading ? 'uploading' : '',
      recording.hasArticles ? 'ready' : '',
      recording.isEmpty ? 'empty' : '',
      recording.phase,
      recording.blockReason,
      recording.title,
      recording.coverPhotoKey,
      recording.tags.join('\u001f')
    ].join('\u001e');
  }

  static applyStatus(recordings: Recording[], stem: string, status: string): Recording[] {
    const target: Recording | undefined = recordings.find(
      (recording: Recording) => recording.stem() === stem);
    if (!target) return recordings;
    target.saving = false;
    target.uploading = false;
    if (status === 'ready') {
      target.hasArticles = true;
      target.isEmpty = false;
      target.phase = '';
    } else if (status === 'empty') {
      target.hasArticles = false;
      target.isEmpty = true;
      target.phase = '';
    } else {
      target.phase = status;
    }
    return recordings.slice();
  }

  static applyArticleMetadata(recordings: Recording[], stem: string, title: string, tags: string[]): Recording[] {
    const target: Recording | undefined = recordings.find(
      (recording: Recording) => recording.stem() === stem);
    if (!target) return recordings;
    target.title = title.trim();
    target.tags = tags.slice();
    return recordings.slice();
  }

  static beginSaving(recordings: Recording[], saving: Recording): Recording[] {
    return [saving].concat(recordings.filter((recording: Recording) => recording.name !== saving.name));
  }

  static finishSaving(recordings: Recording[], savingName: string, pending: Recording): Recording[] {
    return [pending].concat(recordings.filter((recording: Recording) =>
      recording.name !== savingName && recording.name !== pending.name));
  }

  static cancelSaving(recordings: Recording[], savingName: string): Recording[] {
    return recordings.filter((recording: Recording) => recording.name !== savingName);
  }

  static afterSuccessfulDelete(recordings: Recording[], deletedName: string): Recording[] {
    return recordings.filter((recording: Recording) => recording.name !== deletedName);
  }

  static afterRefresh(
    pending: Recording[], remote: Recording[], deletedNames: string[], saving: Recording[] = [],
    previous: Recording[] = []
  ): Recording[] {
    const hidden: Set<string> = new Set<string>(deletedNames);
    const savingNames: Set<string> = new Set<string>();
    saving.forEach((recording: Recording) => savingNames.add(recording.name));
    const previousByName: Map<string, Recording> = new Map<string, Recording>();
    previous.forEach((recording: Recording) => previousByName.set(recording.name, recording));
    remote.forEach((recording: Recording) => {
      const cached: Recording | undefined = previousByName.get(recording.name);
      if (cached && recording.title.length === 0) recording.title = cached.title;
      if (cached && recording.tags.length === 0) recording.tags = cached.tags.slice();
      if (cached && recording.coverPhotoKey.length === 0) recording.coverPhotoKey = cached.coverPhotoKey;
      if (cached && !recording.hasArticles && !recording.isEmpty && recording.phase.length === 0) {
        recording.phase = cached.phase;
      }
    });
    const remoteNames: Set<string> = new Set<string>();
    remote.forEach((recording: Recording) => remoteNames.add(recording.name));
    return saving.filter((recording: Recording) => !hidden.has(recording.name))
      .concat(pending.filter((recording: Recording) =>
        !hidden.has(recording.name) && !remoteNames.has(recording.name) && !savingNames.has(recording.name)))
      .concat(remote.filter((recording: Recording) =>
        !hidden.has(recording.name) && !savingNames.has(recording.name)));
  }
}
