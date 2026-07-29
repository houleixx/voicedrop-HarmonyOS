export class RecordingUploadPolicy {
  static uploadCompleted(audioStored: boolean, _mineTriggered: boolean): boolean {
    // The audio PUT is the upload boundary. /mine is a best-effort compatibility
    // trigger; the current upload endpoint already starts mining server-side.
    return audioStored;
  }
}
