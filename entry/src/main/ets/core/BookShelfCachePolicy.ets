export class BookShelfCachePolicy {
  static identity(digest: string, generation: number): string {
    return `bookShelf.v1.${digest}.g${Math.max(0, Math.floor(generation))}`;
  }

  static canRestore(storedIdentity: string, currentIdentity: string): boolean {
    return currentIdentity.length > 0 && storedIdentity === currentIdentity;
  }

  static shouldAcceptResponse(requestIdentity: string, currentIdentity: string): boolean {
    return requestIdentity.length > 0 && requestIdentity === currentIdentity;
  }
}
