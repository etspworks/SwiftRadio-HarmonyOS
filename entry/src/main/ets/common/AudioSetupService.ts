// file: .ts - pure logic. Port of SwiftRadio/Services/AudioSetupService.swift.
// AVAudioSession + MPRemoteCommandCenter + MPNowPlayingInfoCenter -> @kit.AVSessionKit (type 'audio'),
// background audio -> @kit.BackgroundTasksKit continuous task (BackgroundMode.AUDIO_PLAYBACK).
// Call AudioSetupService.shared.setup(this.context) from EntryAbility.onCreate,
// and teardown() from EntryAbility.onDestroy.
import { avSession } from '@kit.AVSessionKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { common, wantAgent, WantAgent } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Config } from '../model/Config';
import { PlaybackState, PlayerState, RadioPlayer, RadioPlayerEvent, RadioPlayerEventKind, RadioPlayerObserver } from './RadioPlayer';
import { StationsManager } from './StationsManager';
import { ITunesAPI } from './TrackMetadataService';

const DOMAIN: number = 0x0001;
const TAG: string = 'AudioSetup';

// MPNowPlayingInfoCenter.nowPlayingInfo equivalent, filled by StationsManager.updateLockScreen.
export class NowPlayingInfo {
  assetId: string = 'swiftradio';
  title?: string;
  artist?: string;
  artwork?: image.PixelMap;
  isLive: boolean = true;
  elapsed: number = 0;   // seconds
  duration: number = 0;  // seconds
  rate: number = 0;
}

function debugLog(message: string): void {
  if (Config.DEBUG_LOG) {
    hilog.info(DOMAIN, TAG, '%{public}s', message);
  }
}

export class AudioSetupService implements RadioPlayerObserver {
  // Lazy: constructing at module evaluation would touch AppStorage before any UI instance exists.
  private static instance?: AudioSetupService;

  static get shared(): AudioSetupService {
    if (AudioSetupService.instance === undefined) {
      AudioSetupService.instance = new AudioSetupService();
    }
    return AudioSetupService.instance;
  }

  private session?: avSession.AVSession;
  private context?: common.UIAbilityContext;
  private active: boolean = false;
  private backgroundRunning: boolean = false;
  // MPRemoteCommand.isEnabled for the live-dependent stop command.
  private stopCommandIsEnabled: boolean = false;
  private lastInfo: NowPlayingInfo = new NowPlayingInfo();

  private readonly playHandler = (): void => {
    this.player.play();
  };
  // HarmonyOS media controllers send 'pause', never 'stop': a live stream stops, as its in-app button does.
  private readonly pauseHandler = (): void => {
    if (this.player.duration === 0) {
      this.player.stop();
    } else {
      this.player.pause();
    }
  };
  private readonly stopHandler = (): void => {
    this.player.stop();
  };
  private readonly nextHandler = (): void => {
    this.manager.setNext();
  };
  private readonly previousHandler = (): void => {
    this.manager.setPrevious();
  };

  // Lazy: StationsManager and AudioSetupService reference each other (as in the source).
  private get player(): RadioPlayer {
    return RadioPlayer.shared;
  }

  private get manager(): StationsManager {
    return StationsManager.shared;
  }

  async setup(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    await this.setupAudioSession();
    this.setupFRadioPlayer();
    this.setupRemoteCommandCenter();
    this.player.addObserver(this);
  }

  // AVAudioSession .playback -> an 'audio' AVSession, activated.
  async setupAudioSession(): Promise<void> {
    const ctx: common.UIAbilityContext | undefined = this.context;
    if (ctx === undefined || this.session !== undefined) {
      return;
    }
    try {
      const category: avSession.AVSessionType = 'audio';
      this.session = await avSession.createAVSession(ctx, 'SwiftRadio', category);
      await this.session.activate();
      this.active = true;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      debugLog(`Failed to configure audio session: ${err.message}`);
    }
  }

  setupFRadioPlayer(): void {
    this.player.isAutoPlay = true;
    this.player.enableArtwork = true;
    this.player.artworkAPI = new ITunesAPI(600);
  }

  setupRemoteCommandCenter(): void {
    const s: avSession.AVSession | undefined = this.session;
    if (s === undefined) {
      return;
    }
    s.on('play', this.playHandler);
    s.on('pause', this.pauseHandler);
    s.on('playNext', this.nextHandler);
    s.on('playPrevious', this.previousHandler);
    // stop disabled until the first lock-screen update says otherwise.
    this.stopCommandIsEnabled = true;
    this.updateLiveCommands(false);
  }

  updateLiveCommands(isLive: boolean): void {
    const s: avSession.AVSession | undefined = this.session;
    if (s === undefined) {
      return;
    }
    const stopEnabled: boolean = isLive;
    if (stopEnabled !== this.stopCommandIsEnabled) {
      if (stopEnabled) {
        s.on('stop', this.stopHandler);
      } else {
        s.off('stop', this.stopHandler);
      }
      this.stopCommandIsEnabled = stopEnabled;
    }
  }

  activateAudioSession(): void {
    const s: avSession.AVSession | undefined = this.session;
    if (s === undefined) {
      return;
    }
    s.activate().then(() => {
      this.active = true;
    }).catch((err: BusinessError) => {
      debugLog(`audioSession could not be activated: ${err.message}`);
    });
  }

  // Lock screen / control center metadata + state.
  updateNowPlaying(info: NowPlayingInfo): void {
    this.lastInfo = info;
    const s: avSession.AVSession | undefined = this.session;
    if (s === undefined) {
      return;
    }
    const meta: avSession.AVMetadata = {
      assetId: info.assetId,
      title: info.title,
      artist: info.artist,
      mediaImage: info.artwork,
      duration: info.isLive ? -1 : Math.round(info.duration * 1000)
    };
    s.setAVMetadata(meta).catch((err: BusinessError) => debugLog(`setAVMetadata failed: ${err.message}`));
    this.pushPlaybackState();
  }

  async teardown(): Promise<void> {
    await this.stopBackgroundRunning();
    const s: avSession.AVSession | undefined = this.session;
    this.session = undefined;
    this.active = false;
    try {
      await this.player.release();
    } finally {
      if (s !== undefined) {
        await s.destroy();
      }
    }
  }

  // MARK: - RadioPlayerObserver: keep AVSession state + the continuous task in step with playback.

  radioPlayer(player: RadioPlayer, event: RadioPlayerEvent): void {
    if (event.kind === RadioPlayerEventKind.PLAYBACK_STATE_DID_CHANGE ||
      event.kind === RadioPlayerEventKind.PLAYER_STATE_DID_CHANGE) {
      this.pushPlaybackState();
    }
    if (event.kind === RadioPlayerEventKind.PLAYBACK_STATE_DID_CHANGE) {
      if (event.playbackState === PlaybackState.PLAYING) {
        this.activateAudioSession();
        this.startBackgroundRunning();
      } else {
        this.stopBackgroundRunning();
      }
    }
  }

  private pushPlaybackState(): void {
    const s: avSession.AVSession | undefined = this.session;
    if (s === undefined) {
      return;
    }
    let state: avSession.PlaybackState = avSession.PlaybackState.PLAYBACK_STATE_STOP;
    if (this.player.state === PlayerState.ERROR) {
      state = avSession.PlaybackState.PLAYBACK_STATE_ERROR;
    } else if (this.player.playbackState === PlaybackState.PLAYING) {
      state = this.player.state === PlayerState.LOADING ?
        avSession.PlaybackState.PLAYBACK_STATE_BUFFERING : avSession.PlaybackState.PLAYBACK_STATE_PLAY;
    } else if (this.player.playbackState === PlaybackState.PAUSED) {
      state = avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
    }
    const pbs: avSession.AVPlaybackState = {
      state: state,
      // AVSession rejects speed 0 ("invalid parameters") and the card then keeps showing the old state;
      // paused is carried by state, speed is the playback rate (MPNowPlayingInfo's rate 0 has no equivalent).
      speed: 1,
      position: { elapsedTime: Math.round(this.player.currentTime * 1000), updateTime: Date.now() }
    };
    s.setAVPlaybackState(pbs).catch((err: BusinessError) => debugLog(`setAVPlaybackState failed: ${err.message}`));
  }

  private async startBackgroundRunning(): Promise<void> {
    const ctx: common.UIAbilityContext | undefined = this.context;
    if (ctx === undefined || this.backgroundRunning) {
      return;
    }
    this.backgroundRunning = true;
    try {
      const info: wantAgent.WantAgentInfo = {
        wants: [{ bundleName: ctx.abilityInfo.bundleName, abilityName: ctx.abilityInfo.name }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const agent: WantAgent = await wantAgent.getWantAgent(info);
      await backgroundTaskManager.startBackgroundRunning(ctx, backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, agent);
      debugLog('continuous task AUDIO_PLAYBACK started');
    } catch (e) {
      this.backgroundRunning = false;
      const err: BusinessError = e as BusinessError;
      debugLog(`startBackgroundRunning failed: ${err.code} ${err.message}`);
    }
  }

  private async stopBackgroundRunning(): Promise<void> {
    const ctx: common.UIAbilityContext | undefined = this.context;
    if (ctx === undefined || !this.backgroundRunning) {
      return;
    }
    this.backgroundRunning = false;
    try {
      await backgroundTaskManager.stopBackgroundRunning(ctx);
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      debugLog(`stopBackgroundRunning failed: ${err.code} ${err.message}`);
    }
  }
}
