export class RecordingStopPolicy {
  static canFinalize(_stopSucceeded: boolean, hasCompleteM4a: boolean): boolean {
    return hasCompleteM4a;
  }

  static hasCompleteM4a(bytes: Uint8Array): boolean {
    if (bytes.byteLength <= 1024) return false;
    for (let index: number = 0; index <= bytes.byteLength - 4; index++) {
      if (bytes[index] === 109 && bytes[index + 1] === 111 &&
        bytes[index + 2] === 111 && bytes[index + 3] === 118) return true;
    }
    return false;
  }
}
