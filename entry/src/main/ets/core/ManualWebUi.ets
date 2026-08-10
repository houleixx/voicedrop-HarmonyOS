export class ManualWebUi {
  static readonly URL: string = 'https://voicedrop.cn/help/manual/';
  static readonly SECTION_IDS: string[] = ['ch1', 'ch2', 'ch3', 'ch4', 'ch5', 'ch6', 'ch7', 'ch8'];
  static readonly SECTION_LABELS: string[] = [
    '1 上手', '2 录音', '3 改稿', '4 发布',
    '5 社区', '6 文风', '7 账号', '8 FAQ'
  ];

  static isManualUrl(url: string): boolean {
    const normalized: string = url.trim().toLowerCase().split('#')[0].split('?')[0].replace(/\/+$/, '');
    return normalized === 'https://voicedrop.cn/help/manual'
      || normalized === 'https://www.voicedrop.cn/help/manual'
      || normalized === 'https://jianshuo.dev/voicedrop/help/manual'
      || normalized === 'https://www.jianshuo.dev/voicedrop/help/manual';
  }

  static shouldOpenExternally(url: string): boolean {
    return /^https:\/\//i.test(url.trim()) && !ManualWebUi.isManualUrl(url);
  }

  static scrollScript(index: number): string {
    if (index < 0 || index >= ManualWebUi.SECTION_IDS.length) return '';
    return `document.getElementById('${ManualWebUi.SECTION_IDS[index]}')`
      + `.scrollIntoView({behavior:'smooth',block:'start'})`;
  }

  static setupScript(): string {
    return "(function(){"
      + "var old=document.getElementById('vd-native-manual');"
      + "if(!old){var style=document.createElement('style');style.id='vd-native-manual';"
      + "style.textContent='header.site,.hero,nav.toc,footer.site{display:none!important}'"
      + "+'.layout{display:block!important;max-width:780px!important;margin:0 auto!important;padding:5px 20px 72px!important}'"
      + "+'.chapter{scroll-margin-top:12px!important}'"
      + "+'.chapter:first-child{padding-top:0!important}'"
      + "+'.chapter:first-child h2{margin-top:4px!important}'"
      + "+'body{background:#faf6ef!important}';document.head.appendChild(style);}"
      + "var sections=['ch1','ch2','ch3','ch4','ch5','ch6','ch7','ch8'].map(function(id){return document.getElementById(id);});"
      + "window.__vdManualReport=function(){var active=0;for(var i=0;i<sections.length;i++){"
      + "if(sections[i]&&sections[i].getBoundingClientRect().top<=96){active=i;}}"
      + "if(window.__vdManualActive!==active){window.__vdManualActive=active;VoiceDropManual.onSectionChanged(active);}};"
      + "if(!window.__vdManualListening){window.__vdManualListening=true;window.addEventListener('scroll',function(){"
      + "if(!window.__vdManualTick){window.__vdManualTick=true;requestAnimationFrame(function(){window.__vdManualTick=false;window.__vdManualReport();});}});}"
      + "window.__vdManualReport();"
      + "})()";
  }
}

export class ManualSectionSelection {
  private activeSection: number = 0;
  private targetSection: number = -1;

  select(index: number): number {
    this.activeSection = index;
    this.targetSection = index;
    return this.activeSection;
  }

  report(index: number): number {
    if (this.targetSection >= 0) {
      if (index === this.targetSection) this.targetSection = -1;
      return this.activeSection;
    }
    this.activeSection = index;
    return this.activeSection;
  }

  releaseTarget(): void {
    this.targetSection = -1;
  }
}
