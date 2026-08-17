import { ShareExtensionAbility, UIExtensionContentSession, Want } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { ShareImport, ShareIncomingPayload, ShareRecordValue } from '../core/ShareImport';

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
    const payload: ShareIncomingPayload = ShareImport.payloadFromRecords(records);
    this.loadPayload(session, this.hasPayload(payload) ? payload : this.payloadFromWant(want));
  }

  private loadPayload(session: UIExtensionContentSession, payload: ShareIncomingPayload): void {
    const storage: LocalStorage = new LocalStorage();
    storage.setOrCreate<string>('shareType', payload.type);
    storage.setOrCreate<string>('shareUris', JSON.stringify(payload.uris));
    storage.setOrCreate<string>('shareText', payload.text);
    storage.setOrCreate<string>('shareTitle', payload.title);
    session.loadContent('pages/ShareCollectPage', storage);
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
    if (uris.length === 0 && (want.uri ?? '').length > 0 && text.length === 0) uris = [want.uri ?? ''];
    return new ShareIncomingPayload(want.type ?? '', uris, text, title);
  }

  private hasPayload(payload: ShareIncomingPayload): boolean {
    return payload.text.trim().length > 0 || payload.uris.length > 0;
  }
}
