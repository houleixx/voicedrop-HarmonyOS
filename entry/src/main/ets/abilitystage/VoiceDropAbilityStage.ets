import AbilityStage from '@ohos.app.ability.AbilityStage';

// Keep application-stage startup free of SDK and network initialization.
// Business services are activated by Index only after privacy consent.
export default class VoiceDropAbilityStage extends AbilityStage {}
