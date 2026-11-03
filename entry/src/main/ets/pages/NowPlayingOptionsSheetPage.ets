import { LengthMetrics } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { RadioStation } from '../model/RadioStation';
import { FRadioPlayerMetadata } from '../model/TrackMetadata';
import { BottomSheetOption, BottomSheetOptionKind } from '../model/BottomSheetOption';
import { StationsManager } from '../common/StationsManager';
import { ShareService, BottomSheetHost } from '../common/ShareService';
import { describeError } from '../common/ErrorText';
import { stationArtwork } from '../components/StationCell';
import { LogoShareView } from '../components/LogoShareView';

// Capture S0007/S0012 (dark, elevated sheet): systemBackground #1C1C1E, cells
// secondarySystemGroupedBackground #2C2C2E, .label white, .tertiaryLabel #EBEBF5@0.30,
// separator #545458@0.60; 44 vp rows, 20 vp card inset, 10 vp card radius, body 17.
class SheetStyle {
  static readonly SHEET_BACKGROUND: string = '#1C1C1E';
  static readonly CELL_FILL: string = '#2C2C2E';
  static readonly LABEL: string = '#FFFFFF';
  static readonly TERTIARY_LABEL: string = '#4DEBEBF5';
  static readonly SEPARATOR: string = '#99545458';
  static readonly SEPARATOR_WIDTH: number = 0.5;
  static readonly SEPARATOR_INSET: number = 61;
  static readonly BODY_SIZE: number = 17;
  static readonly ICON_SIZE: number = 24;
  static readonly ICON_TEXT_GAP: number = 17;
  static readonly ROW_HEIGHT: number = 44;
  static readonly ROW_PADDING_H: number = 20;
  static readonly CARD_RADIUS: number = 10;
  static readonly SECTION_GAP: number = 35;
  static readonly INSET_H: number = 20;
  static readonly INSET_TOP: number = 12;
  static readonly INSET_BOTTOM: number = 36;
}

// MainCoordinator closes the popup and pushes/opens in the same step. Here a router push issued
// while the Now Playing cover is still transitioning is lost, so the follow-up is handed to the
// host (StationsListPage) through AppStorage and runs in the cover's onDisappear - the moment the
// cover is gone, with no Stations-only gap.

// screen_bottom_sheet: OVERLAY (source: BottomSheetViewController, presented from Now Playing
// with prefersGrabberVisible + a content-height detent). Mounted by NowPlayingPlayer.bindSheet.
// Row tap = tableView(didSelectRowAt): delegate (NowPlayingViewController.bottomSheet ->
// MainCoordinator.didSelectBottomSheetOption / BottomSheetHandler.handle), then dismiss.
@Component
export struct NowPlayingOptionsSheet {
  @Link showOptions: boolean;
  @StorageLink('currentStation') currentStation: RadioStation | undefined = undefined;
  // player.currentArtworkURL ('' = nil): feeds the share card.
  @StorageLink('currentArtworkURL') currentArtworkURL: string = '';
  @StorageLink('currentMetadata') currentMetadata: FRadioPlayerMetadata | undefined = undefined;
  @StorageLink('popupOpen') popupOpen: boolean = false;

  // Option.title (Content.BottomSheet.*)
  private titleOf(option: BottomSheetOption): Resource {
    switch (option.kind) {
      case BottomSheetOptionKind.INFO:
        return $r('app.string.bottomSheet_aboutStation');
      case BottomSheetOptionKind.WEBSITE:
        return $r('app.string.bottomSheet_stationWebsite');
      default:
        return $r('app.string.bottomSheet_shareNowPlaying');
    }
  }

  private host(): BottomSheetHost {
    const h: BottomSheetHost = {
      context: getContext(this) as common.UIAbilityContext,
      showStationInfo: (station: RadioStation): void => {
        this.openInfo(station);
      }
    };
    return h;
  }

  // MainCoordinator .info: push InfoDetailViewController(station) + closePopup. The host pushes
  // the detail page from the cover's onDisappear; the detail page shows the current station.
  private openInfo(station: RadioStation): void {
    AppStorage.setOrCreate<string>('pendingPush', 'pages/AboutStationStationDetailPage');
    this.showOptions = false;
    this.popupOpen = false;
  }

  // BottomSheetHandler .website: closePopup, then SFSafariViewController(station.website) - the
  // host opens it from the cover's onDisappear.
  private openWebsite(station: RadioStation): void {
    const website: string | undefined = station.website;
    if (website === undefined || website.length === 0) {
      this.popupOpen = false;
      return;
    }
    AppStorage.setOrCreate<string>('pendingLink', website);
    this.popupOpen = false;
  }

  private select(option: BottomSheetOption): void {
    // The live instance (getters: trackName, shoutout).
    const station: RadioStation | undefined = StationsManager.shared.currentStation;
    this.showOptions = false;
    if (station === undefined) {
      return;
    }
    switch (option.kind) {
      case BottomSheetOptionKind.INFO:
        this.openInfo(station);
        break;
      case BottomSheetOptionKind.WEBSITE:
        // closePopup, then SFSafariViewController(station.website) (BottomSheetHandler .website):
        // same ordering as .info - open once the overlays are gone.
        this.openWebsite(station);
        break;
      default:
        this.share(station);
        break;
    }
  }

  // NowPlayingViewController.getTrackArtwork: currentArtworkURL ?? station image.
  private artwork(): ResourceStr {
    if (this.currentArtworkURL !== '') {
      return this.currentArtworkURL;
    }
    return stationArtwork(this.currentStation);
  }

  // ShareActivity.generateImage: render LogoShareView, then share [shoutout, image]. A failed
  // render shares the shoutout alone.
  private share(station: RadioStation): void {
    const host: BottomSheetHost = this.host();
    this.getUIContext().getComponentSnapshot().createFromBuilder((): void => {
      this.shareCard();
    }, 320).then((pixelMap: image.PixelMap): void => {
      ShareService.handle(BottomSheetOption.share(pixelMap), station, host);
    }).catch((e: BusinessError): void => {
      hilog.warn(0x0001, 'OptionsSheet', 'share card render failed: %{public}s', describeError(e));
      ShareService.handle(BottomSheetOption.share(), station, host);
    });
  }

  // A custom-component root gets an unsized Stack around it, capped at the window width, which
  // cut the 600x600 card to a 376-wide strip; a sized root keeps the whole card.
  @Builder
  shareCard() {
    Column() {
      LogoShareView({
        albumArt: this.artwork(),
        radioShoutout: this.currentStation !== undefined ? this.currentStation.shoutout : '',
        trackTitle: this.currentMetadata?.trackName ??
          (this.currentStation !== undefined ? this.currentStation.name : ''),
        trackArtist: this.currentMetadata?.artistName ??
          (this.currentStation !== undefined ? this.currentStation.desc : '')
      })
    }
    .width(600)
    .height(600)
  }

  // Option.image (SF symbol) -> the nearest HarmonyOS system symbol. The website row (Safari's
  // compass on iOS, Apple's mark) shows a globe.
  private glyphOf(option: BottomSheetOption): Resource {
    switch (option.kind) {
      case BottomSheetOptionKind.INFO:
        return $r('sys.symbol.info_circle');
      case BottomSheetOptionKind.WEBSITE:
        return $r('sys.symbol.worldclock');
      case BottomSheetOptionKind.SHARE:
        return $r('sys.symbol.share');
      default:
        return $r('sys.symbol.music');
    }
  }

  // cellForRowAt: one row per Option; every cell carries the same accessibilityIdentifier.
  // defaultContentConfiguration: image + text, tinted .label (.tertiaryLabel when disabled).
  @Builder
  optionRow(option: BottomSheetOption, enabled: boolean) {
    ListItem() {
      Row() {
        SymbolGlyph(this.glyphOf(option))
          .fontSize(SheetStyle.ICON_SIZE)
          .fontColor([enabled ? SheetStyle.LABEL : SheetStyle.TERTIARY_LABEL])
          .width(SheetStyle.ICON_SIZE)
          .height(SheetStyle.ICON_SIZE)
        Text(this.titleOf(option))
          .fontSize(SheetStyle.BODY_SIZE)
          .fontWeight(FontWeight.Regular)
          .fontColor(enabled ? SheetStyle.LABEL : SheetStyle.TERTIARY_LABEL)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .margin({ start: LengthMetrics.vp(SheetStyle.ICON_TEXT_GAP) })
      }
      .width('100%')
      .height(SheetStyle.ROW_HEIGHT)
      .padding({ start: LengthMetrics.vp(SheetStyle.ROW_PADDING_H), end: LengthMetrics.vp(SheetStyle.ROW_PADDING_H) })
      .alignItems(VerticalAlign.Center)
    }
    .id('bottom_sheet_itemroot')
    .enabled(enabled)
    .onClick(() => {
      this.select(option);
    })
  }

  // Sections (getOptions(for:)): [info, website if hasValidWebsite], [share].
  // UITableView(style: .insetGrouped) on .systemBackground (elevated sheet, dark).
  // sheet.prefersGrabberVisible: the system grabber dismisses ONLY the sheet - Now Playing
  // (popupOpen) stays presented underneath.
  private closeViaGrabber(): void {
    this.showOptions = false;
  }

  @Builder
  grabber() {
    Row() {
      Column()
        .width(36)
        .height(5)
        .borderRadius(2.5)
        .backgroundColor('#7F7F7F')
    }
    .width('100%')
    .height(44)
    .justifyContent(FlexAlign.Center)
    .id('sheet_grabber')
    .accessibilityText('Sheet Grabber')
    .onClick(() => {
      this.closeViaGrabber();
    })
  }

  build() {
    Column() {
      this.grabber()
      List({ space: SheetStyle.SECTION_GAP }) {
        ListItemGroup() {
          this.optionRow(BottomSheetOption.info(), true)
          if (this.currentStation !== undefined && this.currentStation.website !== undefined &&
            this.currentStation.hasValidWebsite) {
            this.optionRow(BottomSheetOption.website(), true)
          }
        }
        .divider({
          strokeWidth: SheetStyle.SEPARATOR_WIDTH,
          color: SheetStyle.SEPARATOR,
          startMargin: SheetStyle.SEPARATOR_INSET
        })
        .backgroundColor(SheetStyle.CELL_FILL)
        .borderRadius(SheetStyle.CARD_RADIUS)
        .clip(true)
        ListItemGroup() {
          this.optionRow(BottomSheetOption.share(), true)
        }
        .backgroundColor(SheetStyle.CELL_FILL)
        .borderRadius(SheetStyle.CARD_RADIUS)
        .clip(true)
      }
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
      .padding({
        start: LengthMetrics.vp(SheetStyle.INSET_H),
        end: LengthMetrics.vp(SheetStyle.INSET_H),
        top: LengthMetrics.vp(SheetStyle.INSET_TOP),
        bottom: LengthMetrics.vp(SheetStyle.INSET_BOTTOM)
      })
    }
    .id('screen_bottom_sheet')
    .width('100%')
    .backgroundColor(SheetStyle.SHEET_BACKGROUND)
  }
}
