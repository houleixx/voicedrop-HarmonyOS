/** Author edits share the profile name; hidden only affects public listings. */
export class BookWritingOptions {
  static nameToSave(draft: string, loaded: string | undefined): string | undefined {
    const trimmed: string = draft.trim();
    if (loaded === undefined) return trimmed.length > 0 ? trimmed : undefined;
    return trimmed === loaded ? undefined : trimmed;
  }

  static loadedDraft(current: string, edited: boolean, name: string): string {
    return edited ? current : name;
  }
}
