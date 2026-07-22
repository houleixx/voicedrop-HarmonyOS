import { Recording } from '../model/Models';

export class RecordingListUi {
  static readonly deleteMessage: string = '音频和已挖出的文章都会从云端删除，不可恢复。';

  static afterSuccessfulDelete(recordings: Recording[], deletedName: string): Recording[] {
    return recordings.filter((recording: Recording) => recording.name !== deletedName);
  }

  static afterRefresh(pending: Recording[], remote: Recording[], deletedNames: string[]): Recording[] {
    const hidden: Set<string> = new Set<string>(deletedNames);
    const remoteNames: Set<string> = new Set<string>();
    remote.forEach((recording: Recording) => remoteNames.add(recording.name));
    return pending.filter((recording: Recording) => !hidden.has(recording.name) && !remoteNames.has(recording.name))
      .concat(remote.filter((recording: Recording) => !hidden.has(recording.name)));
  }
}
