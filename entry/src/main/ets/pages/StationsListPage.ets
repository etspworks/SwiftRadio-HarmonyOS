import { common } from '@kit.AbilityKit';
import { StationsManager } from '../common/StationsManager';
import { LinkOpener } from '../common/LinkOpener';
import { RadioPlayer } from '../common/RadioPlayer';
import { ArrayDataSource } from '../common/ArrayDataSource';
import { RadioStation } from '../model/RadioStation';
import { FRadioPlayerMetadata } from '../model/TrackMetadata';
import { Config } from '../model/Config';
import { GradientBackground } from '../components/GradientBackground';
import { StationCell, stationArtwork } from '../components/StationCell';
import { NothingFoundCell } from '../components/NothingFoundCell';
import { NowPlayingIndicator } from '../components/NowPlayingIndicator';
import { PopupMiniPlayer } from '../components/PopupMiniPlayer';
import { AboutSwiftRadio } from './AboutSwiftRadioPage';
import { NowPlayingPlayer } from './NowPlayingPlayerPage';

// screen_stations: source StationsViewController (+ MainCoordinator delegate). Hosts two
// overlays: About (MainCoordinator.openAbout, page-sheet modal) -> bindSheet;
// Now Playing (LNPopupController openPopup) -> bindContentCover on AppStorage 'popupOpen'.
@Entry
@Component
struct StationsListPage {
  @Watch('onStationsChange') @StorageLink('stations') stations: RadioStation[] = [];
  // StationsManager.updateSearch result (shown while the search is active)
  @StorageLink('searchedStations') @Watch('onStationsChange') searchedStations: RadioStation[] = [];
  @StorageLink('currentStation') currentStation: RadioStation | undefined = undefined;
  @StorageLink('isPlaying') isPlaying: boolean = false;
  @StorageLink('isBuffering') isBuffering: boolean = false;
  @StorageLink('currentMetadata') currentMetadata: FRadioPlayerMetadata | undefined = undefined;
  @StorageLink('duration') duration: number = 0;
  @StorageLink('currentTime') currentTime: number = 0;
  @StorageLink('popupBarPresented') popupBarPresented: boolean = false;
  @StorageLink('popupOpen') popupOpen: boolean = false;
  @StorageLink('pendingOverlay') pendingOverlay: string = '';
  // Deep link to a page the source always PUSHES over this host (InfoDetail; Features /
  // Libraries / Contributors from inside the About sheet): pushed once the host is up.
  @StorageLink('pendingPush') pendingPush: string = '';
  @State aboutShown: boolean = false;
  @State isRefreshing: boolean = false;
  // searchController.isActive
  @State @Watch('onStationsChange') searchActive: boolean = false;
  // Both hosts bind the cover to one AppStorage flag: only the page on screen presents it.
  // Starts false: an overlay bound true during the page's first render (before the page node is
  // attached) mounts broken — the cover's child components are torn down, the sheet never shows.
  @State isVisible: boolean = false;
  // Config.searchable: the search field is rendered only when it is true.
  private searchable: boolean = Config.SEARCHABLE;
  private dataSource: ArrayDataSource<RadioStation> = new ArrayDataSource<RadioStation>([]);

  onStationsChange(): void {
    this.dataSource.reload(this.displayedStations());
    // A deep link that needs a current station waits for the stations to load (see below).
    if (this.isVisible && this.stations.length > 0 && this.needsStation()) {
      this.consumePendingOverlay();
    }
  }

  // Now Playing, its options sheet and InfoDetail are only ever opened in the source after
  // MainCoordinator.didSelectStation has made a station current.
  private needsStation(): boolean {
    return this.pendingOverlay === 'now_playing' || this.pendingOverlay === 'bottom_sheet' ||
      this.pendingPush === 'pages/AboutStationStationDetailPage';
  }

  // numberOfRowsInSection / cellForRowAt: searchedStations while searching, else stations
  private displayedStations(): RadioStation[] {
    return this.searchActive ? this.searchedStations : this.stations;
  }

  onPageShow(): void {
    this.isVisible = true;
    this.consumePendingOverlay();
  }

  // Overlays a deep link asked for are presented here, after the page is attached.
  private consumePendingOverlay(): void {
    if (this.needsStation() && StationsManager.shared.currentStation === undefined) {
      if (this.stations.length === 0) {
        return; // re-run from onStationsChange once the bundled stations are loaded
      }
      // Reproduce the precondition through the row-tap path (set + popup bar).
      this.selectStation(this.stations[0]);
    }
    if (this.pendingOverlay === 'about') {
      this.pendingOverlay = '';
      this.aboutShown = true;
      // a pendingPush is pushed from the sheet's onAppear, so it lands above the sheet
    } else if (this.pendingOverlay === 'now_playing' || this.pendingOverlay === 'bottom_sheet') {
      // 'bottom_sheet' is consumed by NowPlayingPlayer once the cover is up.
      if (this.pendingOverlay === 'now_playing') {
        this.pendingOverlay = '';
      }
      this.popupOpen = true;
    } else if (this.pendingPush !== '') {
      setTimeout((): void => {
        this.pushPending();
      }, 0);
    }
  }

  private pushPending(): void {
    const url: string = this.pendingPush;
    if (url === '') {
      return;
    }
    this.pendingPush = '';
    this.getUIContext().getRouter().pushUrl({ url: url }).catch((e: Error): void => {
      console.error(`StationsListPage deep-link push ${url} failed: ${e.message}`);
    });
  }

  private openPendingLink(): void {
    const url: string = AppStorage.get<string>('pendingLink') ?? '';
    if (url === '') {
      return;
    }
    AppStorage.setOrCreate<string>('pendingLink', '');
    LinkOpener.open(getContext(this) as common.UIAbilityContext, url);
  }

  onPageHide(): void {
    this.isVisible = false;
  }

  aboutToAppear(): void {
    this.dataSource.reload(this.displayedStations());
    // Deep-linked straight here (no loader pass): load the stations ourselves.
    if (this.stations.length === 0) {
      StationsManager.shared.fetch(getContext(this)).catch((): void => {
        this.stations = [];
      });
    }
  }

  // StationsViewController.refresh: manager.fetch(), end refreshing after 2 s.
  private refresh(): void {
    // source manager.fetch() has no completion: a failed refresh keeps the current list
    StationsManager.shared.fetch(getContext(this)).catch((err: Error): void => {
      console.error(`StationsListPage refresh failed: ${err.message}`);
    });
    setTimeout((): void => {
      this.isRefreshing = false;
    }, 2000);
  }

  // MainCoordinator.didSelectStation
  private selectStation(station: RadioStation): void {
    const isNewStation: boolean = !station.equals(StationsManager.shared.currentStation);
    if (isNewStation) {
      StationsManager.shared.set(station);
      this.popupBarPresented = true;
    } else if (RadioPlayer.shared.isPlaying) {
      this.popupOpen = true;
    } else {
      RadioPlayer.shared.togglePlaying();
    }
  }

  // NowPlayingViewController.popupBarPlayPauseTapped
  private popupPlayPause(): void {
    if (RadioPlayer.shared.isPlaying && RadioPlayer.shared.duration === 0) {
      RadioPlayer.shared.stop();
    } else {
      RadioPlayer.shared.togglePlaying();
    }
  }

  // NowPlayingViewController.updatePopupBarMetadata
  private popupTitle(): string {
    const station: RadioStation | undefined = this.currentStation;
    const track: string | undefined = this.currentMetadata?.trackName;
    if (track !== undefined) {
      const artist: string | undefined = this.currentMetadata?.artistName;
      return artist !== undefined ? `${track} — ${artist}` : track;
    }
    return station !== undefined ? station.name : '';
  }

  private popupSubtitle(): string {
    const station: RadioStation | undefined = this.currentStation;
    if (station === undefined) {
      return '';
    }
    return this.currentMetadata?.trackName !== undefined ? station.name : station.desc;
  }

  // updatePopupBarPlayPauseButton: playing -> stop.fill (live) / pause.fill, else play.fill
  private popupPlayPauseIcon(): string {
    if (!this.isPlaying) {
      return 'play';
    }
    return this.duration === 0 ? 'stop' : 'pause';
  }

  @Builder
  aboutSheet() {
    AboutSwiftRadio({ aboutShown: $aboutShown })
  }

  // The cover's root must be a system container: with a bare custom component as the builder
  // root, the modal keeps only its frame nodes and destroys the NowPlayingPlayer view at once,
  // so its child components (artwork, controls) never render.
  @Builder
  nowPlayingCover() {
    Column() {
      NowPlayingPlayer()
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      GradientBackground()

      Column() {
        // Navigation bar: leftBarButtonItem menu, large title, rightBarButtonItem indicator
        Row() {
          // UIBarButtonItem(image: line.3.horizontal), tint Config.tintColor (white)
          Button({ type: ButtonType.Normal }) {
            SymbolGlyph($r('sys.symbol.line_3_horizontal'))
              .fontSize(24)
              .fontColor(['#FFFFFF'])
          }
          .width(44)
          .height(44)
          .backgroundColor(Color.Transparent)
          .accessibilityText('Menu')
          .id('stations_menu')
          .onClick((): void => {
            this.aboutShown = true;
          })
          Blank()
          if (this.currentStation !== undefined && (this.isPlaying || this.isBuffering)) {
            NowPlayingIndicator({
              isPlaying: this.isPlaying,
              isBuffering: this.isBuffering,
              onTap: (): void => {
                this.popupOpen = true;
              }
            })
          }
        }
        .width('100%')
        .height(44)
        .padding({ left: 8, right: 16 })

        // prefersLargeTitles: large title (34pt bold) under the bar
        Text($r('app.string.stations_title'))
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .width('100%')
          .padding({ left: 16, right: 16, top: 6, bottom: 8 })

        // setupSearchController: only when Config.searchable
        if (this.searchable) {
          // the page background is always black: light text whatever the system color mode
          Search({ placeholder: 'Search' })
            .fontColor('#FFFFFF')
            .placeholderColor('#99FFFFFF')
            .backgroundColor('#26FFFFFF')
            .id('stations_search')
            .accessibilityText('Search stations')
            .onChange((filter: string): void => {
              // updateSearchResults: manager.updateSearch(with:) + reloadData.
              // Note: "active" = non-empty text; UISearchController is also active while
              // focused with empty text (which shows zero rows) — model focus if ever needed.
              StationsManager.shared.updateSearch(filter);
              this.searchActive = filter.length > 0;
            })
        }

        Refresh({ refreshing: $$this.isRefreshing }) {
          List() {
            if (this.stations.length === 0) {
              ListItem() {
                NothingFoundCell({ text: $r('app.string.stations_loadingMessage') })
              }
            } else {
              LazyForEach(this.dataSource, (station: RadioStation) => {
                ListItem() {
                  StationCell({
                    station: station,
                    isPlaying: this.isPlaying,
                    isBuffering: this.isBuffering,
                    isCurrentStation: station.equals(this.currentStation)
                  })
                }
                .height(104)
                .id('stations_itemroot')
                .accessibilityText('Station row')
                .onClick((): void => {
                  this.selectStation(station);
                })
              }, (station: RadioStation) => station.name + station.streamURL)
            }
          }
          .width('100%')
          .height('100%')
          .backgroundColor(Color.Transparent)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
        .id('stations_refresh')
        .onRefreshing((): void => {
          this.refresh();
        })
        .layoutWeight(1)
        .padding({ bottom: this.popupBarPresented && this.currentStation !== undefined ? 66 : 0 })
      }
      .width('100%')
      .height('100%')

      if (this.popupBarPresented && this.currentStation !== undefined) {
        PopupMiniPlayer({
          title: this.popupTitle(),
          subtitle: this.popupSubtitle(),
          image: stationArtwork(this.currentStation),
          progress: this.duration > 0 ? this.currentTime / this.duration : 0,
          playPause: this.popupPlayPauseIcon(),
          onOpen: (): void => {
            this.popupOpen = true;
          },
          onPlayPause: (): void => {
            this.popupPlayPause();
          }
        })
      }
    }
    .id('screen_stations')
    .width('100%')
    .height('100%')
    .bindSheet(this.aboutShown, this.aboutSheet(), {
      height: SheetSize.LARGE,
      mode: SheetMode.EMBEDDED,
      // page sheet: swipe down dismisses (verified on device); the bar only draws with several
      // detents, and the source page sheet shows no grabber either
      dragBar: true,
      showClose: false,
      backgroundColor: '#1C1C1E',
      onAppear: () => {
        // AboutCoordinator pushes Features / Libraries / Contributors over the sheet; the
        // embedded sheet stays on this page, so Back returns to it still presented.
        this.pushPending();
      },
      onDisappear: () => {
        this.aboutShown = false;
      }
    })
    .bindContentCover(this.popupOpen && this.isVisible, this.nowPlayingCover(), {
      modalTransition: ModalTransition.DEFAULT,
      onDisappear: () => {
        if (this.isVisible) {
          this.popupOpen = false;
          // Options-sheet follow-ups (MainCoordinator .info / .website) run the moment the
          // cover has finished dismissing: a push issued mid-transition is lost.
          this.pushPending();
          this.openPendingLink();
        }
      }
    })
  }
}
