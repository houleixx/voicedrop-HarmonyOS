export class CommunityReplyUi {
  static headerHeight(_recording: boolean): number {
    return 64;
  }

  static savedMessage(uploaded: boolean): string {
    return uploaded ? '回应已保存，成文后自动发布' : '回应已保存，网络恢复后继续上传';
  }

  static shouldRemainOnDetail(communityReply: boolean, recordingSaved: boolean): boolean {
    return communityReply && !recordingSaved;
  }
}
