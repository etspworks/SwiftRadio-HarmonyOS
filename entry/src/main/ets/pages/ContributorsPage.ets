import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { NetworkService } from '../common/NetworkService';
import { describeError } from '../common/ErrorText';
import { ArrayDataSource } from '../common/ArrayDataSource';
import { LinkOpener } from '../common/LinkOpener';
import { Contributor } from '../model/GitHub';
import { ContributorCell } from '../components/ContributorCell';

class ContributorsParams {
  owner: string = '';
  repo: string = '';
}

// screen_contributors: source ContributorsViewController, pushed from About (credits row)
// with owner/repo. 3-column grid of ContributorCell; spinner as background while fetching.
// Back pops to About.
@Entry
@Component
struct ContributorsPage {
  @State contributors: Contributor[] = [];
  @State isLoading: boolean = true;
  @State error: string | null = null;
  // UINavigationBar large title collapses to the inline title once the grid scrolls under it.
  @State titleCollapsed: boolean = false;
  private scroller: Scroller = new Scroller();
  private owner: string = 'analogcode';
  private repo: string = 'Swift-Radio-Pro';
  private dataSource: ArrayDataSource<Contributor> = new ArrayDataSource<Contributor>([]);

  aboutToAppear(): void {
    const p: ContributorsParams | undefined = router.getParams() as ContributorsParams | undefined;
    if (p !== undefined && p.owner !== undefined && p.owner.length > 0) {
      this.owner = p.owner;
      this.repo = p.repo;
    }
    this.fetchContributors();
  }

  private async fetchContributors(): Promise<void> {
    this.error = null;
    this.isLoading = true;
    try {
      const decoded: Contributor[] = await NetworkService.fetchContributors(this.owner, this.repo);
      const sorted: Contributor[] = decoded.sort((a: Contributor, b: Contributor): number =>
        b.contributions - a.contributions);
      this.contributors = sorted;
      this.dataSource.reload(sorted);
    } catch (e) {
      hilog.warn(0x0001, 'Contributors', 'Failed to fetch contributors: %{public}s', JSON.stringify(e));
      this.error = (await NetworkService.isOnline()) ? describeError(e as BusinessError) :
        'No internet connection. Connect to Wi-Fi or mobile data and try again.';
    } finally {
      this.isLoading = false;
    }
  }

  // didSelectItemAt -> SFSafariViewController(contributor.htmlURL)
  private openContributor(contributor: Contributor): void {
    LinkOpener.open(getContext(this) as common.UIAbilityContext, contributor.htmlURL);
  }

  build() {
    Column() {
      // Navigation bar: back button (chevron + "Back" at rest, chevron only when collapsed),
      // tint Config.tintColor (white); inline centred title shown only when collapsed.
      Stack() {
      if (this.titleCollapsed) {
        Text($r('app.string.contributors_title'))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
      }
      Row() {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(22)
              .fontColor(['#FFFFFF'])
            // captured back item reads "Back" at rest (the long previous title collapses to
            // it); scrolled capture shows the chevron only.
            if (!this.titleCollapsed) {
              Text('Back')
                .fontSize(17)
                .fontColor('#FFFFFF')
            }
          }
        }
        .height(44)
        .padding({ left: 8, right: 8 })
        .backgroundColor(Color.Transparent)
        .id('back')
        .accessibilityText('Back, About Swift Radio')
        .onClick(() => {
          router.back();
        })
        Blank()
      }
      .width('100%')
      .height(44)
      }
      .width('100%')
      .height(44)

      // largeTitleDisplayMode .automatic: large title (34pt bold) under the bar, at rest only
      if (!this.titleCollapsed) {
        Text($r('app.string.contributors_title'))
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .width('100%')
          .padding({ left: 16, right: 16, top: 6, bottom: 8 })
      }

      Stack() {
        // fetch succeeded -> grid of contributors; fetch threw -> spinner stops, error stack
        Grid(this.scroller) {
          LazyForEach(this.dataSource, (contributor: Contributor, index: number) => {
            GridItem() {
              ContributorCell({ rank: index + 1, contributor: contributor })
            }
            .id('contributors_itemroot')
            .onClick(() => {
              this.openContributor(contributor);
            })
          }, (contributor: Contributor) => contributor.login)
        }
        // flow layout: 3 columns, interitem 8, line 16, section insets 16
        .columnsTemplate('1fr 1fr 1fr')
        .columnsGap(8)
        .rowsGap(16)
        .padding(16)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .onDidScroll(() => {
          // collapse once content scrolls past the large title; expand back at the top
          const y: number = this.scroller.currentOffset().yOffset;
          const collapsed: boolean = y > 8;
          if (collapsed !== this.titleCollapsed) {
            this.titleCollapsed = collapsed;
          }
        })
        .width('100%')
        .height('100%')

        // collectionView.backgroundView = spinner, animating while fetchContributors is in flight
        if (this.isLoading && this.contributors.length === 0) {
          LoadingProgress()
            .width(48)
            .height(48)
            .color('#99EBEBF5')
        } else if (this.error !== null && this.contributors.length === 0) {
          // Same error stack as the Loader: title, message, Try again.
          Column({ space: 16 }) {
            Text($r('app.string.loader_errorTitle'))
              .textAlign(TextAlign.Center)
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
            Text(this.error ?? '')
              .textAlign(TextAlign.Center)
              .fontSize(13)
              .fontColor('#FFFFFF')
            Button($r('app.string.loader_retryButton'), { type: ButtonType.Normal })
              .fontSize(17)
              .fontColor('#0A84FF')
              .backgroundColor(Color.Transparent)
              .height(44)
              .id('contributors_retry')
              .onClick(() => {
                this.fetchContributors();
              })
          }
          .width('70%')
          .alignItems(HorizontalAlign.Center)
        }
      }
      .layoutWeight(1)
    }
    .id('screen_contributors')
    .width('100%')
    .height('100%')
    // systemGroupedBackground inside the About page sheet (elevated dark)
    .backgroundColor('#1C1C1E')
  }
}
