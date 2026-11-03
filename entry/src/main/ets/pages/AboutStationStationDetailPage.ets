import { router, LengthMetrics } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { StationsManager } from '../common/StationsManager';
import { RadioPlayer } from '../common/RadioPlayer';
import { LinkOpener } from '../common/LinkOpener';
import { RadioStation } from '../model/RadioStation';
import { FRadioPlayerMetadata } from '../model/TrackMetadata';
import { GradientBackground } from '../components/GradientBackground';
import { PopupMiniPlayer } from '../components/PopupMiniPlayer';
import { stationArtwork } from '../components/StationCell';
import { resolveStationImage, StationImageRef } from '../common/StationImage';
import { NowPlayingPlayer } from './NowPlayingPlayerPage';

// InfoDetailViewController styling over the BaseController gradient (styleBaseline tokens:
// label white, largeTitle 34 bold, navBar 44, mini-player 64).
class DetailStyle {
  static readonly LABEL: string = '#FFFFFF';
  static readonly DESC: string = '#B3FFFFFF';
  static readonly LONG_DESC: string = '#D9FFFFFF';
  static readonly SEPARATOR: string = '#26FFFFFF';
  static readonly CHEVRON_TINT: string = '#4DFFFFFF';
  static readonly HAIRLINE: number = 0.5;
  static readonly LARGE_TITLE: number = 34;
  static readonly TITLE2: number = 22;
  static readonly SUBHEADLINE: number = 15;
  static readonly BODY: number = 17;
  static readonly BODY_LINE: number = 22;
  static readonly IMAGE_SIZE: number = 160;
  static readonly IMAGE_RADIUS: number = 20;
  static readonly LINK_ICON: number = 24;
  static readonly CHEVRON: number = 18;
  static readonly BACK_GLYPH: number = 22;
  static readonly NAV_BAR_HEIGHT: number = 44;
}

class InfoDetailParams {
  station: string = '';
}

// screen_info_detail: source InfoDetailViewController (a BaseController: full-bleed gradient),
// pushed over the stations list from the options sheet with the current station. Tree:
// scrollView > contentStack [image (160, top 24), name + desc, separator, longDesc,
// (separator + link buttons when hasValidWebsite)]. Back pops; the mini-player stays docked
// and re-opens Now Playing (bindContentCover on AppStorage 'popupOpen').
@Entry
@Component
struct AboutStationStationDetailPage {
  @State station: RadioStation | undefined = undefined;
  @StorageLink('stations') stations: RadioStation[] = [];
  @StorageLink('currentStation') currentStation: RadioStation | undefined = undefined;
  @StorageLink('isPlaying') isPlaying: boolean = false;
  @StorageLink('currentMetadata') currentMetadata: FRadioPlayerMetadata | undefined = undefined;
  @StorageLink('duration') duration: number = 0;
  @StorageLink('currentTime') currentTime: number = 0;
  @StorageLink('popupBarPresented') popupBarPresented: boolean = false;
  @StorageLink('popupOpen') popupOpen: boolean = false;
  // Both hosts bind the cover to one AppStorage flag: only the page on screen presents it.
  @State isVisible: boolean = true;

  onPageShow(): void {
    this.isVisible = true;
  }

  onPageHide(): void {
    this.isVisible = false;
  }

  aboutToAppear(): void {
    const p: InfoDetailParams | undefined = router.getParams() as InfoDetailParams | undefined;
    const name: string = p !== undefined && p.station !== undefined ? p.station : '';
    const match: RadioStation | undefined = this.stations.find((s: RadioStation) => s.name === name);
    this.station = match !== undefined ? match : StationsManager.shared.currentStation;
  }

  // station.getImage: remote imageURL loads over the network, else the bundled station art.
  private stationImage(): ResourceStr {
    if (this.station === undefined) {
      return stationArtwork(undefined);
    }
    const ref: StationImageRef = resolveStationImage(this.station.imageURL);
    return ref.remoteUrl !== undefined ? ref.remoteUrl : stationArtwork(this.station);
  }

  // linkTapped: SFSafariViewController(station website)
  private openWebsite(): void {
    const website: string | undefined = this.station !== undefined ? this.station.website : undefined;
    LinkOpener.open(getContext(this) as common.UIAbilityContext, website);
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

  // The cover's root must be a system container (see StationsListPage.nowPlayingCover).
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
        // Navigation bar: back (previous title 'Swift Radio', backButtonDisplayMode .minimal ->
        // chevron only) + large title Content.StationDetail.title
        Row() {
          Button() {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(DetailStyle.BACK_GLYPH)
              .fontColor([DetailStyle.LABEL])
          }
          .id('swift_radio')
          .accessibilityText('Swift Radio')
          .height(DetailStyle.NAV_BAR_HEIGHT)
          .padding({ start: LengthMetrics.vp(8), end: LengthMetrics.vp(8) })
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            router.back();
          })
        }
        .width('100%')
        .height(DetailStyle.NAV_BAR_HEIGHT)
        Text($r('app.string.stationDetail_title'))
          .fontSize(DetailStyle.LARGE_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(DetailStyle.LABEL)
          .maxLines(1)
          .width('100%')
          .padding({ start: LengthMetrics.vp(16), end: LengthMetrics.vp(16) })
          .margin({ top: 2, bottom: 8 })
        Scroll() {
          Column() {
            // stationImageView: 160x160, cornerRadius 20, top 24
            Image(this.stationImage())
              .alt($r('app.media.stationImage'))
              .width(DetailStyle.IMAGE_SIZE)
              .height(DetailStyle.IMAGE_SIZE)
              .objectFit(ImageFit.Cover)
              .borderRadius(DetailStyle.IMAGE_RADIUS)
              .clip(true)
              .margin({ top: 24, bottom: 16 })
            // nameLabel: title2 bold, white, centered, 2 lines
            Text(this.station !== undefined ? this.station.name : '')
              .maxLines(2)
              .fontSize(DetailStyle.TITLE2)
              .fontWeight(600)
              .fontColor(DetailStyle.LABEL)
              .textAlign(TextAlign.Center)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .padding({ start: LengthMetrics.vp(20), end: LengthMetrics.vp(20) })
            // descLabel: subheadline, white 70%, centered (titleStack spacing 4)
            Text(this.station !== undefined ? this.station.desc : '')
              .maxLines(2)
              .fontSize(DetailStyle.SUBHEADLINE)
              .fontColor(DetailStyle.DESC)
              .textAlign(TextAlign.Center)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .padding({ start: LengthMetrics.vp(20), end: LengthMetrics.vp(20) })
              .margin({ top: 4, bottom: 24 })
            // separator: white 15%, hairline, inset 20
            Divider()
              .strokeWidth(DetailStyle.HAIRLINE)
              .color(DetailStyle.SEPARATOR)
              .margin({ left: 20, right: 20 })
            // longDescLabel: body, white 85%, inset 20 on every side
            if (this.station !== undefined && this.station.longDesc.length > 0) {
              Text(this.station.longDesc)
                .fontSize(DetailStyle.BODY)
                .fontColor(DetailStyle.LONG_DESC)
                .lineHeight(DetailStyle.BODY_LINE)
                .width('100%')
                .padding(20)
            } else {
              Text($r('app.string.stationDetail_defaultDescription'))
                .fontSize(DetailStyle.BODY)
                .fontColor(DetailStyle.LONG_DESC)
                .lineHeight(DetailStyle.BODY_LINE)
                .width('100%')
                .padding(20)
            }
            if (this.station !== undefined && this.station.website !== undefined &&
              this.station.hasValidWebsite) {
              Divider()
                .strokeWidth(DetailStyle.HAIRLINE)
                .color(DetailStyle.SEPARATOR)
                .margin({ left: 20, right: 20 })
              // makeLinkButton: link image (Safari's compass on iOS, a globe here), imagePadding 10,
              // insets 14/20, trailing chevron tinted white @ 30%.
              Row() {
                SymbolGlyph($r('sys.symbol.worldclock'))
                  .fontSize(DetailStyle.LINK_ICON)
                  .fontColor([DetailStyle.LABEL])
                  .width(DetailStyle.LINK_ICON)
                  .height(DetailStyle.LINK_ICON)
                Text($r('app.string.stationDetail_visitWebsite'))
                  .layoutWeight(1)
                  .fontSize(DetailStyle.BODY)
                  .fontColor(DetailStyle.LABEL)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ start: LengthMetrics.vp(10) })
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(DetailStyle.CHEVRON)
                  .fontColor([DetailStyle.CHEVRON_TINT])
              }
              .width('100%')
              .padding({
                start: LengthMetrics.vp(20),
                end: LengthMetrics.vp(20),
                top: LengthMetrics.vp(14),
                bottom: LengthMetrics.vp(14)
              })
              .alignItems(VerticalAlign.Center)
              .id('info_detail_link_itemroot')
              .onClick(() => {
                this.openWebsite();
              })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
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
    .id('screen_info_detail')
    .width('100%')
    .height('100%')
    .bindContentCover(this.popupOpen && this.isVisible, this.nowPlayingCover(), {
      modalTransition: ModalTransition.DEFAULT,
      onDisappear: () => {
        if (this.isVisible) {
          this.popupOpen = false;
        }
      }
    })
  }
}
