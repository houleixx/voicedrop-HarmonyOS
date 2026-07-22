import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { window } from '@kit.ArkUI';
import { Hypium } from '@ohos/hypium';
import testsuite from '../test/List.test';

const TEST_DESTROYED = -2;

export default class TestAbility extends UIAbility {
  private delegator: abilityDelegatorRegistry.AbilityDelegator = abilityDelegatorRegistry.getAbilityDelegator();

  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    const args: abilityDelegatorRegistry.AbilityDelegatorArgs = abilityDelegatorRegistry.getArguments();
    Hypium.hypiumTest(this.delegator, args, testsuite);
  }

  onDestroy(): void {
    this.delegator.finishTest('TestAbility destroyed unexpectedly', TEST_DESTROYED, () => {});
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('testability/pages/Index');
  }
}
