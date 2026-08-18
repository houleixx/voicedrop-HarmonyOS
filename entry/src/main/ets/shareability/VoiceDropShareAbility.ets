import { ShareExtensionAbility, UIExtensionContentSession, Want } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { ShareImport, ShareIncomingPayload, ShareRecordValue } from '../core/ShareImport';
import { sharePageStorage } from '../share/SharePageStorage';

export default class VoiceDropShareAbility extends ShareExtensionAbility {
  onSessionCreate(want: Want, session: UIExtensionContentSession): void {
    this.loadSharePage(want, session).catch(() => {
      this.loadPayload(session, this.payloadFromWant(want));
    });
  }

  private async loadSharePage(want: Want, session: UIExtensionContentSession): Promise<void> {
    const data: systemShare.SharedData = await systemShare.getSharedData(want);
    const records: ShareRecordValue[] = data.getRecords().map((record: systemShare.SharedRecord) =>
      new ShareRecordValue(record.utd, record.content ?? '', record.uri ?? '', record.title ?? '',
        record.description ?? ''));
    const payload: ShareIncomingPayload = ShareImport.mergePayload(
      ShareImport.payloadFromRecords(records), this.payloadFromWant(want));
    this.loadPayload(session, payload);
  }

  private loadPayload(session: UIExtensionContentSession, payload: ShareIncomingPayload): void {
    sharePageStorage.setOrCreate<string>('shareType', payload.type);
    sharePageStorage.setOrCreate<string>('shareUris', JSON.stringify(payload.uris));
    sharePageStorage.setOrCreate<string>('shareText', payload.text);
    sharePageStorage.setOrCreate<string>('shareTitle', payload.title);
    session.loadContent('pages/ShareCollectPage', sharePageStorage);
  }

  private payloadFromWant(want: Want): ShareIncomingPayload {
    const parameters: Record<string, Object> = want.parameters ?? {};
    const text: string = String(parameters['ohos.extra.param.key.shareUrl'] ??
      parameters['ohos.extra.param.key.content'] ?? parameters['ohos.extra.param.key.shareAbstract'] ?? '');
    const title: string = String(parameters['ohos.extra.param.key.contentTitle'] ?? '');
    const streams: Object | undefined = parameters['ability.params.stream'];
    let uris: string[] = [];
    if (typeof streams === 'string') uris = [streams];
    else if (Array.isArray(streams)) uris = (streams as Object[])
      .map((value: Object) => String(value)).filter((value: string) => value.length > 0);
    const wantUri: string = (want.uri ?? '').trim();
    if (text.length === 0 && ShareImport.isWebUrl(wantUri)) {
      return new ShareIncomingPayload(want.type ?? '', uris, wantUri, title);
    }
    if (uris.length === 0 && wantUri.length > 0 && text.length === 0) uris = [wantUri];
    return new ShareIncomingPayload(want.type ?? '', uris, text, title);
  }
}
