// file: .ts - pure logic. Port of SwiftRadio/Model/StationsManager.swift (singleton store +
// observer list + MPNowPlayingInfoCenter lock-screen update -> AVSession via AudioSetupService).
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { RadioStation } from '../model/RadioStation';
import { decodePixelMap, NetworkService } from './NetworkService';
import { PlayerState, RadioPlayer, RadioPlayerEvent, RadioPlayerEventKind, RadioPlayerObserver } from './RadioPlayer';
import { StationImageRef } from './StationImage';
import { AudioSetupService, NowPlayingInfo } from './AudioSetupService';

// AppStorage keys the UI binds with @StorageProp / @StorageLink.
export const KEY_STATIONS: string = 'stations';
export const KEY_CURRENT_STATION: string = 'currentStation';
export const KEY_SEARCHED_STATIONS: string = 'searchedStations';

// StationsManagerObserver's two callbacks, one discriminated event.
export enum StationsManagerEventKind {
  STATIONS_DID_UPDATE = 'stationsDidUpdate',
  STATION_DID_CHANGE = 'stationDidChange'
}

export class StationsManagerEvent {
  kind: StationsManagerEventKind;
  stations: RadioStation[] = [];
  station?: RadioStation;

  constructor(kind: StationsManagerEventKind) {
    this.kind = kind;
  }
}

export interface StationsManagerObserver {
  stationsManager(manager: StationsManager, event: StationsManagerEvent): void;
}

function sameList(a: RadioStation[], b: RadioStation[]): boolean {
  if (a.length !== b.length) {
    return false;
  }
  for (let i = 0; i < a.length; i++) {
    if (!a[i].equals(b[i])) {
      return false;
    }
  }
  return true;
}

export class StationsManager implements RadioPlayerObserver {

  // Lazy: constructing at module evaluation would touch AppStorage before any UI instance exists.
  private static instance?: StationsManager;

  static get shared(): StationsManager {
    if (StationsManager.instance === undefined) {
      StationsManager.instance = new StationsManager();
    }
    return StationsManager.instance;
  }

  private stationList: RadioStation[] = [];
  private current?: RadioStation;
  searchedStations: RadioStation[] = [];

  private observations: StationsManagerObserver[] = [];
  private context?: common.Context;
  // Bumped per artwork request so a slow fetch never overwrites a newer lock-screen image.
  private artworkGeneration: number = 0;

  private constructor() {
    this.player.addObserver(this);
    this.publish();
  }

  private get player(): RadioPlayer {
    return RadioPlayer.shared;
  }

  get stations(): RadioStation[] {
    return this.stationList;
  }

  private setStations(value: RadioStation[]): void {
    this.stationList = value;
    AppStorage.setOrCreate<RadioStation[]>(KEY_STATIONS, value);
    const e: StationsManagerEvent = new StationsManagerEvent(StationsManagerEventKind.STATIONS_DID_UPDATE);
    e.stations = value;
    this.notifiyObservers((o: StationsManagerObserver) => o.stationsManager(this, e));
  }

  get currentStation(): RadioStation | undefined {
    return this.current;
  }

  private setCurrentStation(value: RadioStation | undefined): void {
    this.current = value;
    AppStorage.setOrCreate<RadioStation | undefined>(KEY_CURRENT_STATION, value);
    const e: StationsManagerEvent = new StationsManagerEvent(StationsManagerEventKind.STATION_DID_CHANGE);
    e.station = value;
    this.notifiyObservers((o: StationsManagerObserver) => o.stationsManager(this, e));
    this.resetArtwork(value);
  }

  // Throws NetworkError (or a Kit BusinessError); the loader shows describeError(err) + retry.
  async fetch(context: common.Context): Promise<void> {
    this.context = context;
    const stations: RadioStation[] = await NetworkService.fetchStations(context);
    if (sameList(this.stationList, stations)) {
      return;
    }
    this.setStations(stations);
    const cur: RadioStation | undefined = this.current;
    if (cur !== undefined && !stations.some((s: RadioStation) => s.equals(cur))) {
      this.reset();
    }
  }

  set(station: RadioStation | undefined): void {
    if (station === undefined) {
      this.reset();
      return;
    }
    this.setCurrentStation(station);
    this.player.radioURL = station.streamURL;
  }

  setNext(): void {
    const index: number | undefined = this.getIndex(this.current);
    if (index === undefined) {
      return;
    }
    const next: RadioStation = (index + 1 === this.stationList.length) ? this.stationList[0] : this.stationList[index + 1];
    this.setCurrentStation(next);
    this.player.radioURL = next.streamURL;
  }

  setPrevious(): void {
    const index: number | undefined = this.getIndex(this.current);
    if (index === undefined) {
      return;
    }
    const previous: RadioStation = (index === 0) ? this.stationList[this.stationList.length - 1] : this.stationList[index - 1];
    this.setCurrentStation(previous);
    this.player.radioURL = previous.streamURL;
  }

  updateSearch(filter: string): void {
    const f: string = filter.toLowerCase();
    this.searchedStations = this.stationList.filter((s: RadioStation) => s.name.toLowerCase().includes(f));
    AppStorage.setOrCreate<RadioStation[]>(KEY_SEARCHED_STATIONS, this.searchedStations);
  }

  private reset(): void {
    this.setCurrentStation(undefined);
    this.player.radioURL = undefined;
  }

  private getIndex(station: RadioStation | undefined): number | undefined {
    if (station === undefined) {
      return undefined;
    }
    const i: number = this.stationList.findIndex((s: RadioStation) => s.equals(station));
    return i >= 0 ? i : undefined;
  }

  // MARK: - Observation

  addObserver(observer: StationsManagerObserver): void {
    if (this.observations.indexOf(observer) < 0) {
      this.observations.push(observer);
    }
  }

  removeObserver(observer: StationsManagerObserver): void {
    const i: number = this.observations.indexOf(observer);
    if (i >= 0) {
      this.observations.splice(i, 1);
    }
  }

  private notifiyObservers(action: (observer: StationsManagerObserver) => void): void {
    const list: StationsManagerObserver[] = this.observations.slice();
    for (const o of list) {
      action(o);
    }
  }

  private publish(): void {
    AppStorage.setOrCreate<RadioStation[]>(KEY_STATIONS, this.stationList);
    AppStorage.setOrCreate<RadioStation | undefined>(KEY_CURRENT_STATION, this.current);
    AppStorage.setOrCreate<RadioStation[]>(KEY_SEARCHED_STATIONS, this.searchedStations);
  }

  // MARK: - Lock screen (MPNowPlayingInfoCenter -> AVSession)

  private resetArtwork(station: RadioStation | undefined): void {
    this.artworkGeneration++;
    const gen: number = this.artworkGeneration;
    if (station === undefined) {
      this.updateLockScreen(undefined);
      return;
    }
    this.loadStationImage(station).then((pm: image.PixelMap | undefined) => {
      if (gen === this.artworkGeneration) {
        this.updateLockScreen(pm);
      }
    });
  }

  // station.getImage(): remote URL, else bundled media, with the 'stationImage' fallback.
  private async loadStationImage(station: RadioStation): Promise<image.PixelMap | undefined> {
    const ref: StationImageRef = station.getImage();
    if (ref.remoteUrl !== undefined) {
      const remote: image.PixelMap | undefined = await NetworkService.fetchImage(ref.remoteUrl);
      if (remote !== undefined) {
        return remote;
      }
    }
    const ctx: common.Context | undefined = this.context;
    if (ctx === undefined) {
      return undefined;
    }
    try {
      const bytes: Uint8Array = ctx.resourceManager.getMediaByNameSync(ref.mediaName);
      const copy: Uint8Array = bytes.slice(0);
      return await decodePixelMap(copy.buffer as ArrayBuffer);
    } catch (e) {
      return undefined;
    }
  }

  private updateLockScreen(artworkImage: image.PixelMap | undefined): void {
    const info: NowPlayingInfo = new NowPlayingInfo();
    info.artwork = artworkImage;
    const station: RadioStation | undefined = this.current;
    if (station !== undefined) {
      info.artist = station.artistName;
      info.title = station.trackName;
      info.assetId = station.streamURL;
    }
    const isLive: boolean = this.player.duration === 0;
    info.isLive = isLive;
    if (!isLive) {
      info.elapsed = this.player.currentTime;
      info.duration = this.player.duration;
      info.rate = this.player.rate;
    }
    AudioSetupService.shared.updateNowPlaying(info);
    AudioSetupService.shared.updateLiveCommands(isLive);
  }

  // MARK: - RadioPlayerObserver

  radioPlayer(player: RadioPlayer, event: RadioPlayerEvent): void {
    switch (event.kind) {
      case RadioPlayerEventKind.PLAYER_STATE_DID_CHANGE:
        // Refresh when loading finishes so duration (live vs file) is accurate.
        if (event.state === PlayerState.READY_TO_PLAY || event.state === PlayerState.LOADING_FINISHED) {
          this.resetArtwork(this.current);
        }
        break;
      case RadioPlayerEventKind.METADATA_DID_CHANGE:
        this.resetArtwork(this.current);
        break;
      case RadioPlayerEventKind.ARTWORK_DID_CHANGE:
        this.artworkDidChange(event.artworkURL);
        break;
      default:
        break;
    }
  }

  private artworkDidChange(artworkURL: string | undefined): void {
    if (artworkURL === undefined) {
      this.resetArtwork(this.current);
      return;
    }
    this.artworkGeneration++;
    const gen: number = this.artworkGeneration;
    NetworkService.fetchImage(artworkURL).then((pm: image.PixelMap | undefined) => {
      if (gen !== this.artworkGeneration) {
        return;
      }
      if (pm === undefined) {
        this.resetArtwork(this.current);
      } else {
        this.updateLockScreen(pm);
      }
    });
  }
}
