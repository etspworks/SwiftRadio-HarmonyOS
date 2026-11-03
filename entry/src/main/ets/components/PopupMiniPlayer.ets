// LNPopupController bar (MainCoordinator.presentPopupBarIfNeeded + NowPlayingViewController
// popupItem) rebuilt as an ArkUI component docked by its HOST page. barStyle .prominent,
// tintColor Config.tintColor (white), progressViewStyle .bottom. Tapping the bar opens the
// Now Playing cover (host callback); the bar button is popupBarPlayPauseTapped.
@Component
export struct PopupMiniPlayer {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop image: ResourceStr = '';
  // popupItem.progress; stays 0 for live streams (duration 0), the bar still shows its track
  @Prop progress: number = 0;
  // 'play' | 'pause' | 'stop' (updatePopupBarPlayPauseButton: play.fill / pause.fill / stop.fill)
  @Prop playPause: string = 'play';
  onOpen?: () => void;
  onPlayPause?: () => void;

  // play.fill / pause.fill have exact system symbols. stop.fill has none (the system stop symbols
  // are circled), so 'stop' draws the same filled rounded square with a Rect.
  private glyph(): Resource {
    if (this.playPause === 'pause') {
      return $r('sys.symbol.pause_fill');
    }
    return $r('sys.symbol.play_fill');
  }

  build() {
    Column() {
      Row({ space: 16 }) {
        Image(this.image)
          .alt($r('app.media.stationImage'))
          .width(48)
          .height(48)
          .objectFit(ImageFit.Cover)
          .borderRadius(4)
          .clip(true)
        Column({ space: 2 }) {
          Text(this.title)
            .fontSize(17)
            .fontColor('#FFFFFF')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.subtitle)
            .fontSize(15)
            .fontColor('#99EBEBF5')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Button({ type: ButtonType.Normal }) {
          if (this.playPause === 'stop') {
            // stop.fill at 24 pt: an 18 pt square with rounded corners
            Rect()
              .width(18)
              .height(18)
              .radius(3)
              .fill('#FFFFFF')
          } else {
            SymbolGlyph(this.glyph())
              .fontSize(24)
              .fontColor(['#FFFFFF'])
          }
        }
        .width(44)
        .height(44)
        .backgroundColor(Color.Transparent)
        .id('now_playing_popup_play_pause')
        .accessibilityText('Mini-player play/stop')
        .onClick((): void => {
          if (this.onPlayPause !== undefined) {
            this.onPlayPause();
          }
        })
      }
      .width('100%')
      .height(64)
      .padding({ left: 16, right: 12 })
      Progress({ value: this.progress, total: 1, type: ProgressType.Linear })
        .width('100%')
        .height(2)
        .color('#FFFFFF')
        .backgroundColor('#33FFFFFF')
        .accessibilityText('Mini-player progress')
    }
    .width('100%')
    .backgroundColor('#F2262628')
    .border({ width: { top: 0.5 }, color: { top: '#545458' } })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    .id('PopupBarView')
    .accessibilityText('Mini-player bar')
    .onClick((): void => {
      if (this.onOpen !== undefined) {
        this.onOpen();
      }
    })
    // LNPopupController: dragging the bar up opens the popup too.
    .gesture(PanGesture({ direction: PanDirection.Up }).onActionEnd((event: GestureEvent): void => {
      if (event.offsetY < 0 && this.onOpen !== undefined) {
        this.onOpen();
      }
    }))
  }
}
