import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit';
import { Want } from '@kit.AbilityKit';

export default class OpenHarmonyTestRunner implements TestRunner {
  onPrepare(): void {}

  async onRun(): Promise<void> {
    const delegator: abilityDelegatorRegistry.AbilityDelegator = abilityDelegatorRegistry.getAbilityDelegator();
    const args: abilityDelegatorRegistry.AbilityDelegatorArgs = abilityDelegatorRegistry.getArguments();
    const want: Want = {
      bundleName: args.bundleName,
      moduleName: args.parameters['-m'],
      abilityName: 'TestAbility'
    };
    await delegator.startAbility(want);
  }
}
