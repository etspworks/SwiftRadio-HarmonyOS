import { window } from '@kit.ArkUI';
import { RadioStation } from '../model/RadioStation';
import { FRadioPlayerMetadata } from '../model/TrackMetadata';
import { Config } from '../model/Config';
import { RadioPlayer } from '../common/RadioPlayer';
import { StationsManager } from '../common/StationsManager';
import { AlbumArtworkView } from '../components/AlbumArtworkView';
import { ControlsView } from '../components/ControlsView';
import { stationArtwork } from '../components/StationCell';
import { NowPlayingOptionsSheet } from './NowPlayingOptionsSheetPage';

// screen_now_playing: OVERLAY (source: LNPopupController popup content). Mounted full-screen
// by bindContentCover in its host (StationsListPage, AboutStationStationDetailPage).
// Tree (NowPlayingViewController.setupViews): background image + thick dark blur + 30% dim,
// popup chevron close, main stack [AlbumArtworkView (~55%), ControlsView].
// More presents the options sheet (bindSheet) mounted here.
@Component
export struct NowPlayingPlayer {
  @StorageLink('currentStation') currentStation: RadioStation | undefined = undefined;
  @StorageLink('isPlaying') isPlaying: boolean = false;
  @StorageLink('isBuffering') isBuffering: boolean = false;
  @StorageLink('currentMetadata') currentMetadata: FRadioPlayerMetadata | undefined = undefined;
  @StorageLink('currentArtworkURL') currentArtworkURL: string = '';
  @StorageLink('duration') duration: number = 0;
  @StorageLink('currentTime') currentTime: number = 0;
  @StorageLink('popupOpen') popupOpen: boolean = false;
  @StorageLink('pendingOverlay') pendingOverlay: string = '';
  @State showOptions: boolean = false;
  // While the user drags the slider, labels follow the thumb (isSliderSliding).
  @State slidingTime: number = -1;
  private hideNextPreviousButtons: boolean = Config.HIDE_NEXT_PREVIOUS_BUTTONS;
  // The full-screen cover is laid out from the top of the screen; the foreground content keeps
  // below the status bar (mainStackView is pinned to safeAreaLayoutGuide in the source).
  @State topInset: number = 0;

  aboutToAppear(): void {
    window.getLastWindow(getContext(this)).then((w: window.Window): void => {
      const area: window.AvoidArea = w.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.topInset = this.getUIContext().px2vp(area.topRect.height);
    }).catch((e: Error): void => {
      console.error(`NowPlayingPlayer: avoid area unavailable: ${e.message}`);
    });
  }

  // Deep link to the options sheet: present it once the cover is mounted (onAppear), never
  // during the first render, where a bound sheet does not show.
  private consumePendingSheet(): void {
    if (this.pendingOverlay === 'bottom_sheet') {
      this.pendingOverlay = '';
      this.showOptions = true;
    }
  }

  // getTrackArtwork: player.currentArtworkURL ?? currentStation.getImage
  private artwork(): ResourceStr {
    if (this.currentArtworkURL !== '') {
      return this.currentArtworkURL;
    }
    return stationArtwork(this.currentStation);
  }

  private formatSeconds(seconds: number): string {
    if (seconds === 0) {
      return '00:00';
    }
    const min: number = Math.floor(seconds / 60);
    const sec: number = Math.floor(seconds % 60);
    return `${min < 10 ? '0' : ''}${min}:${sec < 10 ? '0' : ''}${sec}`;
  }

  private shownTime(): number {
    return this.slidingTime >= 0 ? this.slidingTime : this.currentTime;
  }

  private handleTimeSlider(value: number, mode: SliderChangeMode): void {
    if (this.duration === 0) {
      return;
    }
    const seekTime: number = value * this.duration;
    if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
      RadioPlayer.shared.seek(seekTime);
      this.slidingTime = -1;
    } else {
      this.slidingTime = seekTime;
    }
  }

  @Builder
  optionsSheet() {
    NowPlayingOptionsSheet({ showOptions: $showOptions })
  }

  build() {
    Stack() {
      // backgroundImageView / backgroundBlurView / backgroundDimView
      Image(this.artwork())
        .alt($r('app.media.stationImage'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      // backgroundBlurView: systemThickMaterialDark
      Column()
        .width('100%')
        .height('100%')
        .backgroundBlurStyle(BlurStyle.Thick, { colorMode: ThemeColorMode.DARK })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      // backgroundDimView: black@0.3
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#4D000000')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      Column() {
        // LNPopupController popupCloseButtonStyle = .chevron (grey, top centre)
        Button({ type: ButtonType.Normal, stateEffect: false }) {
          SymbolGlyph($r('sys.symbol.chevron_compact_down'))
            .fontSize(36)
            .fontColor(['#99EBEBF5'])
        }
        .id('close')
        .accessibilityText('Close')
        .width(64)
        .height(36)
        .backgroundColor(Color.Transparent)
        .margin({ top: 4 })
        .flexShrink(0)
        .onClick(() => {
          this.popupOpen = false;
        })
        // mainStackView: [artwork 55%, controls], spacing 24; insets 8 / 24 / 20.
        Column({ space: 24 }) {
          AlbumArtworkView({
            image: this.artwork(),
            isPlaying: this.isPlaying,
            isBuffering: this.isBuffering
          })
            .layoutWeight(55)
          ControlsView({
            // conditionalVariants hasMetadata/noMetadata: boundTo currentMetadata —
            // title "track — artist" when the stream sends ICY metadata, else station name.
            song: this.currentMetadata !== undefined && this.currentMetadata.trackName !== undefined
              ? this.currentMetadata.trackName : undefined,
            artist: this.currentMetadata !== undefined && this.currentMetadata.trackName !== undefined
              ? this.currentMetadata.artistName : undefined,
            stationName: this.currentStation !== undefined ? this.currentStation.name : '',
            stationDesc: this.currentStation !== undefined ? this.currentStation.desc : '',
            isLive: this.duration === 0,
            isPlaying: this.isPlaying,
            sliderValue: this.duration > 0 ? this.shownTime() / this.duration : 0,
            currentTimeText: this.formatSeconds(this.shownTime()),
            totalTimeText: '-' + this.formatSeconds(this.duration - this.shownTime()),
            hideNextPreviousButtons: this.hideNextPreviousButtons,
            playingAction: (): void => {
              if (RadioPlayer.shared.isPlaying && RadioPlayer.shared.duration === 0) {
                RadioPlayer.shared.stop();
              } else {
                RadioPlayer.shared.togglePlaying();
              }
            },
            nextAction: (): void => {
              StationsManager.shared.setNext();
            },
            previousAction: (): void => {
              StationsManager.shared.setPrevious();
            },
            moreAction: (): void => {
              // handleMoreMenu: guard let station = manager.currentStation.
              if (this.currentStation !== undefined) {
                this.showOptions = true;
              }
            },
            timeAction: (value: number, mode: SliderChangeMode): void => {
              this.handleTimeSlider(value, mode);
            }
          })
            .layoutWeight(45)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 24, right: 24, top: 8, bottom: 20 })
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.topInset })
    }
    .id('screen_now_playing')
    .backgroundColor('#000000')
    .width('100%')
    .height('100%')
    .onAppear(() => {
      this.consumePendingSheet();
    })
    // LNPopupController: swiping the popup content down closes it, like the chevron.
    .gesture(PanGesture({ direction: PanDirection.Down, distance: 20 }).onActionEnd((event: GestureEvent): void => {
      if (event.offsetY > 0) {
        this.popupOpen = false;
      }
    }))
    .bindSheet(this.showOptions, this.optionsSheet(), {
      height: SheetSize.FIT_CONTENT,
      backgroundColor: '#1C1C1E',
      // Grabber is rendered inside the sheet content (sheet_grabber, prefersGrabberVisible).
      dragBar: false,
      showClose: false,
      onDisappear: () => {
        this.showOptions = false;
      }
    })
  }
}
