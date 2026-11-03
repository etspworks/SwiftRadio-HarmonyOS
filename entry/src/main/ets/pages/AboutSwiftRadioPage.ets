import { router, LengthMetrics, promptAction } from '@kit.ArkUI';
import { common, bundleManager } from '@kit.AbilityKit';
import { LinkOpener } from '../common/LinkOpener';
import { ShareService } from '../common/ShareService';
import { About, resolveText } from '../model/Config';
import { InfoItem, InfoItemKind, InfoSection } from '../model/InfoSection';

class ContributorsParams {
  owner: string;
  repo: string;

  constructor(owner: string, repo: string) {
    this.owner = owner;
    this.repo = repo;
  }
}

// One run of the header text: AboutViewController.parseBoldMarkers splits on `**` pairs.
class TextRun {
  text: string;
  bold: boolean;

  constructor(text: string, bold: boolean) {
    this.text = text;
    this.bold = bold;
  }
}

// Dark page-sheet palette (elevated systemGroupedBackground / secondarySystemBackground,
// palette.json dark + capture S0023). Shared label tokens from styleBaseline.
class AboutStyle {
  static readonly BACKGROUND: string = '#1C1C1E';
  static readonly CELL: string = '#2C2C2E';
  static readonly CELL_PRESSED: string = '#3A3A3C';
  static readonly LABEL: string = '#FFFFFF';
  static readonly SECONDARY_LABEL: string = '#99EBEBF5';
  static readonly CHEVRON: string = '#4DEBEBF5';
  static readonly SEPARATOR: string = '#99545458';
  static readonly CLOSE_FILL: string = '#52787880';
  static readonly CLOSE_GLYPH: string = '#A3EBEBF5';
}

// screen_about: OVERLAY (source: page-sheet modal in its own UINavigationController).
// Presented by StationsListPage.bindSheet; AboutCoordinator pushes Features / Libraries /
// Contributors on top (router.pushUrl over the embedded sheet), Close dismisses.
// Tree (AboutViewController): nav bar (title + close) / insetGrouped table with
// tableHeaderView (attributed about text) / sections from Config.About.sections /
// tableFooterView (logo + authors + copyright year).
@Component
export struct AboutSwiftRadio {
  @Link aboutShown: boolean;
  @State showMailError: boolean = false;
  @State appVersion: string = '';
  // setupSections: Config.About.sections.filter { $0.isEnabled }
  private sections: InfoSection[] = About.SECTIONS.filter((s: InfoSection) => s.isEnabled);
  private headerRuns: TextRun[] = [];
  private footerText: string = '';

  async aboutToAppear(): Promise<void> {
    const ctx = getContext(this);
    this.headerRuns = AboutSwiftRadio.parseBoldMarkers(resolveText(ctx, 'about_headerText'));
    // "\(footerAuthors)\n\(copyright) © \(year) \(footerCopyright)"
    this.footerText = `${resolveText(ctx, 'about_footerAuthors')}\n${resolveText(ctx, 'about_copyright')} © ` +
      `${new Date().getFullYear()} ${resolveText(ctx, 'about_footerCopyright')}`;
    // App Version row: versionName, as HarmonyOS Settings > Apps shows it (not iOS "short (build)").
    try {
      const info: bundleManager.BundleInfo =
        await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      this.appVersion = info.versionName;
    } catch (e) {
      this.appVersion = '';
    }
  }

  // listGroupedCell background, cornerRadius 8: round only the group's outer corners.
  private static cellRadius(index: number, count: number): BorderRadiuses {
    const top: number = index === 0 ? 10 : 0;
    const bottom: number = index === count - 1 ? 10 : 0;
    const r: BorderRadiuses = { topLeft: top, topRight: top, bottomLeft: bottom, bottomRight: bottom };
    return r;
  }

  private static parseBoldMarkers(input: string): TextRun[] {
    const runs: TextRun[] = [];
    let remaining: string = input;
    let start: number = remaining.indexOf('**');
    while (start >= 0) {
      if (start > 0) {
        runs.push(new TextRun(remaining.substring(0, start), false));
      }
      remaining = remaining.substring(start + 2);
      const end: number = remaining.indexOf('**');
      if (end < 0) {
        runs.push(new TextRun('**', false));
        break;
      }
      runs.push(new TextRun(remaining.substring(0, end), true));
      remaining = remaining.substring(end + 2);
      start = remaining.indexOf('**');
    }
    if (remaining.length > 0) {
      runs.push(new TextRun(remaining, false));
    }
    return runs;
  }

  private handle(item: InfoItem): void {
    if (item.kind === InfoItemKind.FEATURES) {
      router.pushUrl({ url: 'pages/FeaturesPage' });
    } else if (item.kind === InfoItemKind.LIBRARIES) {
      router.pushUrl({ url: 'pages/OpenSourceLibrariesPage' });
    } else if (item.kind === InfoItemKind.CREDITS) {
      router.pushUrl({
        url: 'pages/ContributorsPage',
        params: new ContributorsParams(item.owner ?? '', item.repo ?? '')
      });
    } else if (item.kind === InfoItemKind.LINK) {
      // SFSafariViewController(url) -> system browser.
      LinkOpener.open(this.abilityContext(), item.url);
    } else if (item.kind === InfoItemKind.EMAIL) {
      // MainCoordinator.openEmail: composer, else showSendMailErrorAlert.
      this.openEmail(item.address ?? '');
    } else if (item.kind === InfoItemKind.SHARE) {
      // MainCoordinator.share(text) -> system share sheet (ShareService).
      ShareService.shareText(this.abilityContext(), resolveText(getContext(this), item.text));
    } else if (item.kind === InfoItemKind.RATE_APP) {
      // No store listing for the port yet: a toast instead of the source's store link.
      try {
        promptAction.showToast({ message: $r('app.string.about_rateApp_unavailable') });
      } catch (e) {
        // a toast that cannot show is no reason to fail the tap
      }
    }
  }

  private abilityContext(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext;
  }

  private async openEmail(address: string): Promise<void> {
    const sent: boolean = await LinkOpener.sendEmail(this.abilityContext(), address);
    // conditionalVariant showMailError: !MFMailComposeViewController.canSendMail()
    this.showMailError = !sent;
    if (this.showMailError) {
      this.showSendMailErrorAlert();
    }
  }

  // UIViewController+Email.showSendMailErrorAlert: title / message / OK (cancel).
  private showSendMailErrorAlert(): void {
    const ctx = getContext(this);
    this.getUIContext().showAlertDialog({
      title: resolveText(ctx, 'common_couldNotSendEmail'),
      message: resolveText(ctx, 'common_emailErrorMessage'),
      confirm: {
        value: resolveText(ctx, 'common_ok'),
        action: () => {
          this.showMailError = false;
        }
      }
    });
  }

  // InfoItem.icon (SF Symbol name) -> the nearest HarmonyOS system symbol. sys.symbol.worldclock
  // draws a plain globe; info (a plain i on iOS) falls back to the circled info symbol.
  private iconFor(sf: string): Resource {
    if (sf === 'list.bullet') {
      return $r('sys.symbol.list_bullet');
    } else if (sf === 'book') {
      return $r('sys.symbol.book');
    } else if (sf === 'heart') {
      return $r('sys.symbol.heart');
    } else if (sf === 'envelope') {
      return $r('sys.symbol.envelope');
    } else if (sf === 'star') {
      return $r('sys.symbol.star');
    } else if (sf === 'globe') {
      return $r('sys.symbol.worldclock');
    } else if (sf === 'square.and.arrow.up') {
      return $r('sys.symbol.share');
    } else if (sf === 'exclamationmark.bubble') {
      return $r('sys.symbol.exclamationmark_message');
    }
    return $r('sys.symbol.info_circle');
  }

  @Builder
  rowContent(item: InfoItem) {
    // defaultContentConfiguration: image (SF symbol, tint .label) + text + secondaryText;
    // accessory disclosure for every row except .version.
    Row() {
      SymbolGlyph(this.iconFor(item.icon))
        .fontSize(24)
        .fontColor([AboutStyle.LABEL])
        .width(28)
      Column() {
        Text(resolveText(getContext(this), item.title))
          .fontSize(17)
          .fontColor(AboutStyle.LABEL)
        if (item.kind === InfoItemKind.VERSION) {
          Text(this.appVersion)
            .fontSize(13)
            .fontColor(AboutStyle.LABEL)
            .margin({ top: 3 })
        } else if (item.subtitle !== undefined) {
          Text(resolveText(getContext(this), item.subtitle))
            .fontSize(13)
            .fontColor(AboutStyle.LABEL)
            .margin({ top: 3 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ start: LengthMetrics.vp(16), end: LengthMetrics.vp(8) })
      if (item.kind !== InfoItemKind.VERSION) {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(14)
          .fontColor([AboutStyle.CHEVRON])
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 44 })
    .padding({ start: LengthMetrics.vp(16), end: LengthMetrics.vp(16), top: LengthMetrics.vp(11), bottom: LengthMetrics.vp(11) })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  tableHeader() {
    // aboutLabel: 17pt secondaryLabel, bold runs, lineSpacing 6; insets 24 / 16.
    Text() {
      ForEach(this.headerRuns, (run: TextRun) => {
        Span(run.text)
          .fontSize(17)
          .fontColor(AboutStyle.SECONDARY_LABEL)
          .fontWeight(run.bold ? FontWeight.Bold : FontWeight.Normal)
      }, (run: TextRun, index: number) => index.toString())
    }
    .lineSpacing(LengthMetrics.vp(6))
    .width('100%')
    .padding({ start: LengthMetrics.vp(16), end: LengthMetrics.vp(16), top: LengthMetrics.vp(24), bottom: LengthMetrics.vp(24) })
  }

  @Builder
  tableFooter() {
    // stackView: vertical, spacing 16, centred; logo 60x60; footnote secondaryLabel; insets 32 / 16.
    Column({ space: 16 }) {
      Image($r('app.media.logo'))
        .width(60)
        .height(60)
        .objectFit(ImageFit.Contain)
      Text(this.footerText)
        .textAlign(TextAlign.Center)
        .fontSize(13)
        .lineHeight(18)
        .fontColor(AboutStyle.SECONDARY_LABEL)
    }
    .width('100%')
    .padding({ start: LengthMetrics.vp(16), end: LengthMetrics.vp(16), top: LengthMetrics.vp(32), bottom: LengthMetrics.vp(32) })
  }

  @Builder
  sectionHeader(title: string) {
    // insetGrouped section header: 13pt uppercase secondaryLabel.
    // Uppercase the string itself, not via textCase: the UI tree must read "FEATURES", or the
    // header is indistinguishable from the "Features" row below it.
    Text(title.toUpperCase())
      .fontSize(13)
      .fontColor(AboutStyle.SECONDARY_LABEL)
      .padding({ start: LengthMetrics.vp(20), end: LengthMetrics.vp(20), top: LengthMetrics.vp(16), bottom: LengthMetrics.vp(7) })
      .width('100%')
  }

  build() {
    Column() {
      // Sheet nav bar: centred inline title (17pt semibold) + system .close circle button.
      Stack({ alignContent: Alignment.End }) {
        Text(resolveText(getContext(this), 'about_title'))
          .fontSize(17)
          .fontWeight(600)
          .fontColor(AboutStyle.LABEL)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ start: LengthMetrics.vp(56), end: LengthMetrics.vp(56) })
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor([AboutStyle.CLOSE_GLYPH])
        }
        .id('about_close')
        .accessibilityText('Close')
        .width(30)
        .height(30)
        .backgroundColor(AboutStyle.CLOSE_FILL)
        .margin({ end: LengthMetrics.vp(12) })
        .onClick(() => {
          this.aboutShown = false;
        })
      }
      .width('100%')
      .height(56)
      List() {
        ListItem() {
          this.tableHeader()
        }
        ForEach(this.sections, (section: InfoSection) => {
          ListItemGroup({ header: this.sectionHeader(resolveText(getContext(this), section.title)) }) {
            ForEach(section.items, (item: InfoItem, index: number) => {
              if (item.kind === InfoItemKind.VERSION) {
                // .version: selectionStyle none, didSelectRowAt ignores it (display only).
                ListItem() {
                  this.rowContent(item)
                }
                .id('about_itemroot')
                .backgroundColor(AboutStyle.CELL)
                .borderRadius(AboutSwiftRadio.cellRadius(index, section.items.length))
              } else {
                ListItem() {
                  this.rowContent(item)
                }
                .id('about_itemroot')
                .backgroundColor(AboutStyle.CELL)
                .borderRadius(AboutSwiftRadio.cellRadius(index, section.items.length))
                .stateStyles({
                  pressed: {
                    .backgroundColor(AboutStyle.CELL_PRESSED)
                  },
                  normal: {
                    .backgroundColor(AboutStyle.CELL)
                  }
                })
                .onClick(() => {
                  this.handle(item);
                })
              }
            }, (item: InfoItem) => item.kind + item.title)
          }
          .padding({ start: LengthMetrics.vp(20), end: LengthMetrics.vp(20), bottom: LengthMetrics.vp(8) })
          .divider({ strokeWidth: 0.5, color: AboutStyle.SEPARATOR, startMargin: 60, endMargin: 0 })
        }, (section: InfoSection) => section.title)
        ListItem() {
          this.tableFooter()
        }
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      // UIScrollView .normal deceleration coasts far further than ArkUI's default friction, so a
      // release at modest velocity stopped the list short of tableFooter; match iOS momentum.
      .friction(0.15)
      // Sheet at its single LARGE detent: the list scrolls first, the sheet only takes the
      // overscroll (swipe-down-to-dismiss from the top edge still works).
      .nestedScroll({ scrollForward: NestedScrollMode.SELF_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
    }
    .id('screen_about')
    .width('100%')
    .height('100%')
    .backgroundColor(AboutStyle.BACKGROUND)
  }
}
