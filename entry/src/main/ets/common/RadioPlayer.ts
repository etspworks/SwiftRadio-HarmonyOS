// file: .ts - pure logic. Replaces FRadioPlayer.shared (external SPM package FRadioPlayer 0.2.2,
// behaviour read from its source, never ported) with @kit.MediaKit AVPlayer.
// Radio streams are progressive http(s) MP3/AAC, which AVPlayer plays directly (no DASH, no file://).
import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { FRadioPlayerMetadata } from '../model/TrackMetadata';
import { ITunesAPI, TrackMetadataService } from './TrackMetadataService';

const DOMAIN: number = 0x0001;
const TAG: string = 'RadioPlayer';

// FRadioPlayer.State
export enum PlayerState {
  URL_NOT_SET = 'urlNotSet',
  READY_TO_PLAY = 'readyToPlay',
  LOADING = 'loading',
  LOADING_FINISHED = 'loadingFinished',
  ERROR = 'error'
}

// FRadioPlayer.PlaybackState
export enum PlaybackState {
  PLAYING = 'playing',
  PAUSED = 'paused',
  STOPPED = 'stopped'
}

// The FRadioPlayerObserver callbacks, one discriminated event.
export enum RadioPlayerEventKind {
  PLAYER_STATE_DID_CHANGE = 'playerStateDidChange',
  PLAYBACK_STATE_DID_CHANGE = 'playbackStateDidChange',
  ITEM_DID_CHANGE = 'itemDidChange',
  METADATA_DID_CHANGE = 'metadataDidChange',
  ARTWORK_DID_CHANGE = 'artworkDidChange',
  DURATION_DID_CHANGE = 'durationDidChange',
  PLAY_TIME_DID_CHANGE = 'playTimeDidChange'
}

export class RadioPlayerEvent {
  kind: RadioPlayerEventKind;
  state?: PlayerState;
  playbackState?: PlaybackState;
  url?: string;
  metadata?: FRadioPlayerMetadata;
  artworkURL?: string;
  duration?: number;
  currentTime?: number;

  constructor(kind: RadioPlayerEventKind) {
    this.kind = kind;
  }
}

export interface RadioPlayerObserver {
  radioPlayer(player: RadioPlayer, event: RadioPlayerEvent): void;
}

// AppStorage keys the UI binds with @StorageProp / @StorageLink.
export const KEY_IS_PLAYING: string = 'isPlaying';
export const KEY_IS_BUFFERING: string = 'isBuffering';
export const KEY_PLAYER_STATE: string = 'playerState';
export const KEY_PLAYBACK_STATE: string = 'playbackState';
export const KEY_DURATION: string = 'duration';
export const KEY_CURRENT_TIME: string = 'currentTime';
export const KEY_CURRENT_METADATA: string = 'currentMetadata';
export const KEY_CURRENT_ARTWORK_URL: string = 'currentArtworkURL';

export class RadioPlayer {
  // Lazy: constructing at module evaluation would touch AppStorage before any UI instance exists.
  private static instance?: RadioPlayer;

  static get shared(): RadioPlayer {
    if (RadioPlayer.instance === undefined) {
      RadioPlayer.instance = new RadioPlayer();
    }
    return RadioPlayer.instance;
  }

  isAutoPlay: boolean = true;
  enableArtwork: boolean = true;
  artworkAPI: ITunesAPI = new ITunesAPI(300);

  private url?: string;
  private playerState: PlayerState = PlayerState.URL_NOT_SET;
  private playback: PlaybackState = PlaybackState.STOPPED;
  private metadata?: FRadioPlayerMetadata;
  private artworkURL?: string;
  private durationSeconds: number = 0;
  private timeSeconds: number = 0;

  private avPlayer?: media.AVPlayer;
  private observers: RadioPlayerObserver[] = [];
  private metadataService: TrackMetadataService = new TrackMetadataService();
  private generation: number = 0;
  private wantsPlay: boolean = false;
  private metadataStarted: boolean = false;
  // Set when this item was reloaded with an open-ended Range header (see the 'prepared' handler).
  private openEndedRange: boolean = false;
  // A seek in flight: timeUpdate still reports the old position until seekDone.
  private seeking: boolean = false;
  // Serialises reset/url assignments so rapid station switches never overlap on one AVPlayer.
  private chain: Promise<void> = Promise.resolve();

  private constructor() {
    this.publish();
  }

  // MARK: - Public surface (FRadioPlayer)

  get radioURL(): string | undefined {
    return this.url;
  }

  set radioURL(url: string | undefined) {
    this.url = url;
    this.radioURLDidChange(url);
  }

  get state(): PlayerState {
    return this.playerState;
  }

  get playbackState(): PlaybackState {
    return this.playback;
  }

  get isPlaying(): boolean {
    return this.playback === PlaybackState.PLAYING;
  }

  get currentMetadata(): FRadioPlayerMetadata | undefined {
    return this.metadata;
  }

  get currentArtworkURL(): string | undefined {
    return this.artworkURL;
  }

  // Seconds; 0 = live stream (no duration).
  get duration(): number {
    return this.durationSeconds;
  }

  get currentTime(): number {
    return this.timeSeconds;
  }

  get rate(): number {
    return this.isPlaying ? 1 : 0;
  }

  addObserver(observer: RadioPlayerObserver): void {
    if (this.observers.indexOf(observer) < 0) {
      this.observers.push(observer);
    }
  }

  removeObserver(observer: RadioPlayerObserver): void {
    const i: number = this.observers.indexOf(observer);
    if (i >= 0) {
      this.observers.splice(i, 1);
    }
  }

  play(): void {
    const p: media.AVPlayer | undefined = this.avPlayer;
    if (p === undefined || this.url === undefined) {
      return;
    }
    this.wantsPlay = true;
    const s: string = p.state; // gate on the live AVPlayer state, never a cached snapshot
    if (s === 'prepared' || s === 'paused' || s === 'completed') {
      p.play().catch((err: BusinessError) => this.onError(err));
    } else if (s === 'stopped') {
      p.prepare().catch((err: BusinessError) => this.onError(err)); // 'prepared' handler plays
    } else if (s === 'idle' || s === 'error') {
      this.enqueueLoad(this.url, this.generation, this.openEndedRange); // item was dropped (live stop / error): reload
    }
    this.setPlaybackState(PlaybackState.PLAYING);
  }

  pause(): void {
    const p: media.AVPlayer | undefined = this.avPlayer;
    if (p === undefined) {
      return;
    }
    this.wantsPlay = false;
    if (p.state === 'playing') {
      p.pause().catch((err: BusinessError) => this.onError(err));
    }
    this.setPlaybackState(PlaybackState.PAUSED);
  }

  stop(): void {
    const p: media.AVPlayer | undefined = this.avPlayer;
    if (p === undefined) {
      return;
    }
    this.wantsPlay = false;
    const s: string = p.state;
    if (this.durationSeconds !== 0) {
      this.setCurrentTime(0);
      if (s === 'playing') {
        p.pause().catch((err: BusinessError) => this.onError(err));
      }
      if (s === 'playing' || s === 'paused' || s === 'prepared' || s === 'completed') {
        p.seek(0);
      }
    } else {
      // Live: drop the item (source replaceCurrentItem(nil)) and clear metadata/artwork.
      if (s === 'prepared' || s === 'playing' || s === 'paused' || s === 'completed') {
        p.stop().catch((err: BusinessError) => this.onError(err));
      }
      this.metadataService.stop();
      this.metadataStarted = false;
      this.setMetadata(undefined);
      this.setArtworkURL(undefined);
    }
    this.setPlaybackState(PlaybackState.STOPPED);
  }

  seek(seconds: number): void {
    const p: media.AVPlayer | undefined = this.avPlayer;
    if (p === undefined || this.durationSeconds === 0) {
      return;
    }
    // Show the target at once (AVPlayer.currentTime does on iOS), not the old position until it lands.
    this.seeking = true;
    this.setCurrentTime(seconds);
    p.seek(Math.round(seconds * 1000), media.SeekMode.SEEK_PREV_SYNC);
    this.play();
  }

  togglePlaying(): void {
    if (this.isPlaying) {
      this.pause();
    } else {
      this.play();
    }
  }

  // Owner teardown (EntryAbility.onDestroy via AudioSetupService.teardown).
  async release(): Promise<void> {
    this.generation++;
    this.metadataService.stop();
    const p: media.AVPlayer | undefined = this.avPlayer;
    this.avPlayer = undefined;
    if (p !== undefined) {
      try {
        await p.reset();
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'RadioPlayer: reset before release failed');
      } finally {
        await p.release();
      }
    }
  }

  // MARK: - Item lifecycle

  private radioURLDidChange(url: string | undefined): void {
    this.generation++;
    const gen: number = this.generation;
    this.resetPlayer();
    if (url === undefined || url.length === 0) {
      this.setPlayerState(PlayerState.URL_NOT_SET);
      this.chain = this.chain.then(async (): Promise<void> => {
        const p: media.AVPlayer | undefined = this.avPlayer;
        if (p !== undefined && p.state !== 'idle' && p.state !== 'released') {
          await p.reset();
        }
      }).catch((err: BusinessError) => this.onError(err));
      this.notify(new RadioPlayerEvent(RadioPlayerEventKind.ITEM_DID_CHANGE));
      return;
    }
    this.setPlayerState(PlayerState.LOADING);
    this.wantsPlay = this.isAutoPlay;
    this.openEndedRange = false;
    this.enqueueLoad(url, gen, false);
    const item: RadioPlayerEvent = new RadioPlayerEvent(RadioPlayerEventKind.ITEM_DID_CHANGE);
    item.url = url;
    this.notify(item);
    if (this.isAutoPlay) {
      this.setPlaybackState(PlaybackState.PLAYING);
    }
  }

  private enqueueLoad(url: string, gen: number, openEndedRange: boolean): void {
    this.chain = this.chain.then(async (): Promise<void> => {
      if (gen !== this.generation) {
        return;
      }
      const p: media.AVPlayer = await this.ensurePlayer();
      if (p.state !== 'idle') {
        await p.reset(); // reset between sources
      }
      if (gen !== this.generation) {
        return;
      }
      if (openEndedRange) {
        await p.setMediaSource(media.createMediaSourceWithUrl(url, { 'Range': 'bytes=0-' }));
      } else {
        p.url = url; // -> 'initialized' -> prepare -> 'prepared' -> play
      }
    }).catch((err: BusinessError) => this.onError(err));
  }

  // Source resetPlayer(): stop + clear item, duration, time, metadata, artwork.
  private resetPlayer(): void {
    this.metadataService.stop();
    this.metadataStarted = false;
    this.seeking = false;
    this.setMetadata(undefined);
    this.setArtworkURL(undefined);
    this.setDuration(0);
    this.setCurrentTime(0);
    this.setPlaybackState(PlaybackState.STOPPED);
  }

  private async ensurePlayer(): Promise<media.AVPlayer> {
    if (this.avPlayer !== undefined) {
      return this.avPlayer;
    }
    const p: media.AVPlayer = await media.createAVPlayer();
    this.avPlayer = p;

    p.on('stateChange', (s: media.AVPlayerState, reason: media.StateChangeReason) => {
      hilog.info(DOMAIN, TAG, 'RadioPlayer: state -> %{public}s', s);
      switch (s) {
        case 'initialized':
          // audioRendererInfo is settable only in 'initialized'.
          p.audioRendererInfo = { usage: audio.StreamUsage.STREAM_USAGE_MUSIC, rendererFlags: 0 };
          p.prepare().catch((err: BusinessError) => this.onError(err));
          break;
        case 'prepared':
          // Some live servers answer the player's ranged probe with a bogus size (streamtheworld sends
          // "content-range: 0-8191/2100000000"), so the stream looks like a half-second file. Asked for
          // an open-ended range they reply 200 with no size, which the player takes as live. Reload before
          // playing, so the progress bar never runs through the fake duration.
          if (!this.openEndedRange && p.duration > 0 && p.duration < 2000 && this.url !== undefined) {
            hilog.info(DOMAIN, TAG, 'RadioPlayer: %{public}d ms item, reloading as live', p.duration);
            this.openEndedRange = true;
            this.enqueueLoad(this.url, this.generation, true);
            break;
          }
          this.setPlayerState(PlayerState.READY_TO_PLAY);
          this.setDuration(p.duration);
          if (this.wantsPlay) {
            p.play().catch((err: BusinessError) => this.onError(err));
          }
          break;
        case 'playing':
          this.setPlayerState(PlayerState.LOADING_FINISHED);
          this.setPlaybackState(PlaybackState.PLAYING);
          this.startMetadata();
          break;
        case 'paused':
          if (this.playback === PlaybackState.PLAYING && !this.wantsPlay) {
            this.setPlaybackState(PlaybackState.PAUSED);
          }
          break;
        case 'completed':
          // itemDidPlayToEnd: pause and rewind.
          this.wantsPlay = false;
          this.setPlaybackState(PlaybackState.PAUSED);
          p.seek(0);
          this.setCurrentTime(0);
          break;
        case 'error':
          this.setPlayerState(PlayerState.ERROR);
          this.setPlaybackState(PlaybackState.STOPPED);
          break;
        default:
          break;
      }
    });
    p.on('error', (err: BusinessError) => this.onError(err));
    p.on('bufferingUpdate', (infoType: media.BufferingInfoType, value: number) => {
      if (infoType === media.BufferingInfoType.BUFFERING_START) {
        this.setPlayerState(PlayerState.LOADING);
      } else if (infoType === media.BufferingInfoType.BUFFERING_END) {
        this.setPlayerState(PlayerState.LOADING_FINISHED);
      }
    });
    p.on('durationUpdate', (ms: number) => {
      if (ms > 0 && ms < 2000 && !this.openEndedRange) {
        return; // the bogus size the 'prepared' handler reloads; never show it
      }
      this.setDuration(ms);
    });
    p.on('seekDone', () => {
      this.seeking = false;
    });
    p.on('timeUpdate', (ms: number) => {
      if (this.durationSeconds !== 0 && !this.seeking) {
        this.setCurrentTime(ms / 1000);
      }
    });
    p.on('audioInterrupt', (info: audio.InterruptEvent) => {
      if (info.hintType === audio.InterruptHint.INTERRUPT_HINT_PAUSE ||
        info.hintType === audio.InterruptHint.INTERRUPT_HINT_STOP) {
        this.pause();
      } else if (info.hintType === audio.InterruptHint.INTERRUPT_HINT_RESUME) {
        this.play();
      }
    });
    return p;
  }

  private onError(err: BusinessError): void {
    hilog.error(DOMAIN, TAG, 'RadioPlayer: error %{public}d %{public}s', err.code, err.message);
    this.seeking = false;
    this.setPlayerState(PlayerState.ERROR);
    this.setPlaybackState(PlaybackState.STOPPED);
  }

  // MARK: - Metadata / artwork

  private startMetadata(): void {
    const url: string | undefined = this.url;
    if (this.metadataStarted || url === undefined) {
      return;
    }
    this.metadataStarted = true;
    const gen: number = this.generation;
    this.metadataService.start(url, (m: FRadioPlayerMetadata | undefined) => {
      if (gen !== this.generation) {
        return;
      }
      const same: boolean = (m === undefined && this.metadata === undefined) ||
        (m !== undefined && this.metadata !== undefined && m.rawValue === this.metadata.rawValue);
      if (!same) {
        this.setMetadata(m);
        this.shouldGetArtwork(m, gen);
      }
    });
  }

  private shouldGetArtwork(m: FRadioPlayerMetadata | undefined, gen: number): void {
    if (!this.enableArtwork) {
      return;
    }
    if (m === undefined) {
      this.setArtworkURL(undefined);
      return;
    }
    this.artworkAPI.getArtwork(m).then((url: string | undefined) => {
      if (gen === this.generation) {
        this.setArtworkURL(url);
      }
    });
  }

  // MARK: - Setters: publish to AppStorage + notify observers

  private setPlayerState(s: PlayerState): void {
    if (this.playerState === s) {
      return;
    }
    this.playerState = s;
    this.publish();
    const e: RadioPlayerEvent = new RadioPlayerEvent(RadioPlayerEventKind.PLAYER_STATE_DID_CHANGE);
    e.state = s;
    this.notify(e);
  }

  private setPlaybackState(s: PlaybackState): void {
    if (this.playback === s) {
      return;
    }
    this.playback = s;
    this.publish();
    const e: RadioPlayerEvent = new RadioPlayerEvent(RadioPlayerEventKind.PLAYBACK_STATE_DID_CHANGE);
    e.playbackState = s;
    this.notify(e);
  }

  private setMetadata(m: FRadioPlayerMetadata | undefined): void {
    if (m === undefined && this.metadata === undefined) {
      return;
    }
    this.metadata = m;
    this.publish();
    const e: RadioPlayerEvent = new RadioPlayerEvent(RadioPlayerEventKind.METADATA_DID_CHANGE);
    e.metadata = m;
    this.notify(e);
  }

  private setArtworkURL(url: string | undefined): void {
    if (url === this.artworkURL) {
      return;
    }
    this.artworkURL = url;
    this.publish();
    const e: RadioPlayerEvent = new RadioPlayerEvent(RadioPlayerEventKind.ARTWORK_DID_CHANGE);
    e.artworkURL = url;
    this.notify(e);
  }

  // AVPlayer reports ms; live streams report 0 or -1 -> 0 (source: indefinite duration == 0).
  private setDuration(ms: number): void {
    const seconds: number = ms > 0 ? ms / 1000 : 0;
    if (seconds === this.durationSeconds) {
      return;
    }
    this.durationSeconds = seconds;
    this.publish();
    const e: RadioPlayerEvent = new RadioPlayerEvent(RadioPlayerEventKind.DURATION_DID_CHANGE);
    e.duration = seconds;
    this.notify(e);
  }

  private setCurrentTime(seconds: number): void {
    if (seconds === this.timeSeconds) {
      return;
    }
    this.timeSeconds = seconds;
    AppStorage.setOrCreate<number>(KEY_CURRENT_TIME, seconds);
    const e: RadioPlayerEvent = new RadioPlayerEvent(RadioPlayerEventKind.PLAY_TIME_DID_CHANGE);
    e.currentTime = seconds;
    e.duration = this.durationSeconds;
    this.notify(e);
  }

  private publish(): void {
    AppStorage.setOrCreate<boolean>(KEY_IS_PLAYING, this.isPlaying);
    AppStorage.setOrCreate<boolean>(KEY_IS_BUFFERING, this.playerState === PlayerState.LOADING);
    AppStorage.setOrCreate<string>(KEY_PLAYER_STATE, this.playerState);
    AppStorage.setOrCreate<string>(KEY_PLAYBACK_STATE, this.playback);
    AppStorage.setOrCreate<number>(KEY_DURATION, this.durationSeconds);
    AppStorage.setOrCreate<number>(KEY_CURRENT_TIME, this.timeSeconds);
    AppStorage.setOrCreate<FRadioPlayerMetadata | undefined>(KEY_CURRENT_METADATA, this.metadata);
    AppStorage.setOrCreate<string>(KEY_CURRENT_ARTWORK_URL, this.artworkURL !== undefined ? this.artworkURL : '');
  }

  private notify(event: RadioPlayerEvent): void {
    const list: RadioPlayerObserver[] = this.observers.slice();
    for (const o of list) {
      o.radioPlayer(this, event);
    }
  }
}
