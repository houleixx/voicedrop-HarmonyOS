export enum PrivacyStartupSurface {
  Pending,
  Consent,
  Business
}

export class PrivacyStartup {
  static accepted(storedVersion: string, requiredVersion: string): boolean {
    return storedVersion.length > 0 && storedVersion === requiredVersion;
  }

  static surface(resolved: boolean, accepted: boolean): PrivacyStartupSurface {
    if (!resolved) return PrivacyStartupSurface.Pending;
    return accepted ? PrivacyStartupSurface.Business : PrivacyStartupSurface.Consent;
  }
}
