import AbilityStage from '@ohos.app.ability.AbilityStage';
import { umengAnalytics } from '../data/UmengAnalytics';

export default class VoiceDropAbilityStage extends AbilityStage {
  onCreate(): void {
    umengAnalytics.preInitialize(this.context.getApplicationContext());
  }
}
