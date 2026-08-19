export enum HomeTabIndex {
  Recordings = 0,
  Community = 1,
  Books = 2
}

export class HomeTabPolicy {
  static shouldLoadCommunity(tab: number, remoteLoaded: boolean, loadPending: boolean): boolean {
    return tab === HomeTabIndex.Community && !remoteLoaded && !loadPending;
  }
}
