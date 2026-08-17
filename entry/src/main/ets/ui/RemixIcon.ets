/**
 * Remix Icon 2.5.0 glyph catalog shared with the VoiceDrop mini program.
 * Font asset: resources/rawfile/remixicon.ttf (Apache-2.0).
 */
export class RemixIconGlyph {
  static readonly ARROW_GO_BACK: string = '\uEA58';
  static readonly ARROW_GO_FORWARD: string = '\uEA5A';
  static readonly ARROW_LEFT: string = '\uEA64';
  static readonly ARROW_RIGHT: string = '\uEA6E';
  static readonly ARROW_UP_LINE: string = '\uEA76';
  static readonly BOOK_OPEN: string = '\uEADB';
  static readonly BOOK_READ: string = '\uEADD';
  static readonly CAMERA_LENS: string = '\uEB30';
  static readonly CHAT: string = '\uEB4F';
  static readonly CHECK: string = '\uEB7B';
  static readonly CLOSE: string = '\uEB99';
  static readonly DELETE: string = '\uEC26';
  static readonly DELETE_BIN_LINE: string = '\uEC2A';
  static readonly DOWNLOAD: string = '\uEC54';
  static readonly EDIT: string = '\uEC80';
  static readonly FILE_COPY: string = '\uECD5';
  static readonly FILE_TEXT: string = '\uED0F';
  static readonly FLAG: string = '\uED3B';
  static readonly FLASHLIGHT_FILL: string = '\uED3C';
  static readonly FLASHLIGHT: string = '\uED3D';
  static readonly FOLDER: string = '\uED6A';
  static readonly HAND_HEART: string = '\uEDF3';
  static readonly HEART_FILL: string = '\uEE0E';
  static readonly HEART: string = '\uEE0F';
  static readonly IMAGE: string = '\uEE4B';
  static readonly INFORMATION: string = '\uEE59';
  static readonly LINK: string = '\uEEB2';
  static readonly LOADER: string = '\uEEC6';
  static readonly MAGIC: string = '\uEEEA';
  static readonly MIC: string = '\uEF50';
  static readonly MORE: string = '\uEF78';
  static readonly PLAY: string = '\uF00A';
  static readonly QUILL_PEN: string = '\uF04A';
  static readonly REFRESH: string = '\uF064';
  static readonly SEARCH: string = '\uF0D1';
  static readonly SEND_PLANE: string = '\uF0D9';
  static readonly SETTINGS: string = '\uF0E8';
  static readonly SHARE_BOX: string = '\uF0F4';
  static readonly SHARE_FORWARD: string = '\uF0FD';
  static readonly TEAM: string = '\uF1EE';
  static readonly USER: string = '\uF264';
  static readonly WECHAT: string = '\uF2B6';
}

@Component
export struct RemixIcon {
  @Prop glyph: string = '';
  @Prop iconSize: number = 24;
  @Prop color: ResourceColor = '#2A2521';

  build() {
    Text(this.glyph)
      .fontFamily('remixicon')
      .fontSize(this.iconSize)
      .fontColor(this.color)
      .textAlign(TextAlign.Center)
  }
}
