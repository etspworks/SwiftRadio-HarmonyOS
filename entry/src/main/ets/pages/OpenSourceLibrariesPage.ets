import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { Libraries } from '../model/Config';
import { LibraryItem } from '../model/InfoSection';
import { LinkOpener } from '../common/LinkOpener';

// screen_libraries: source LibrariesViewController (insetGrouped table), pushed from About.
// One card with a row per HarmonyOS SDK kit the app imports (Config Libraries.ITEMS): kit name,
// import + licence; a tap opens the kit's source / reference. Back pops to About.
@Entry
@Component
struct OpenSourceLibrariesPage {
  private libraries: LibraryItem[] = Libraries.ITEMS;
  // UINavigationBar: back item collapses to chevron-only and the bar gains a translucent
  // blurred fill once the table scrolls under it (rest: chevron + "Back", transparent bar).
  @State titleCollapsed: boolean = false;
  private scroller: Scroller = new Scroller();

  private openLibrary(library: LibraryItem): void {
    LinkOpener.open(getContext(this) as common.UIAbilityContext, library.url);
  }

  build() {
    Column() {
      // Navigation bar: back button (chevron + "Back") and the inline centred title
      Stack() {
        Text($r('app.string.libraries_title'))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
        Row() {
          Button({ type: ButtonType.Normal }) {
            Row({ space: 4 }) {
              SymbolGlyph($r('sys.symbol.chevron_left'))
                .fontSize(22)
                .fontColor(['#FFFFFF'])
              // captured back item reads "Back" at rest (the long previous title collapses
              // to it); scrolled capture shows the chevron only.
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
      }
      .width('100%')
      .height(44)
      // translucent/blurred bar fill once content scrolls under it; transparent at rest
      .backgroundColor(this.titleCollapsed ? '#F2262628' : Color.Transparent)

      // insetGrouped: one rounded card holding every kit
      List({ scroller: this.scroller }) {
        ListItemGroup() {
          ForEach(this.libraries, (library: LibraryItem) => {
            ListItem() {
              // kit name + "import: modules used" and licence, disclosure
              Row() {
                Column({ space: 2 }) {
                  Text(library.name)
                    .fontSize(17)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FFFFFF')
                  Text(library.detail)
                    .fontSize(13)
                    .fontColor('#FFFFFF')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(16)
                  .fontColor(['#4DEBEBF5'])
              }
              .width('100%')
              .padding({ left: 20, right: 16, top: 11, bottom: 11 })
            }
            .id('libraries_itemroot')
            // the row's own tappable subtree carries the trailing disclosure chevron
            // (SymbolGlyph chevron_right above) — label it so it is recognised as part
            // of this row's one click site, not a second control
            .accessibilityText('chevron')
            .onClick(() => {
              this.openLibrary(library);
            })
          }, (library: LibraryItem) => library.name)
        }
        .backgroundColor('#2C2C2E')
        .borderRadius(10)
        .clip(true)
        .divider({ strokeWidth: 0.5, color: '#545458', startMargin: 20, endMargin: 0 })
      }
      // addSpaceAtTopOfTable + insetGrouped 20pt side margins
      .padding({ left: 20, right: 20, top: 28, bottom: 20 })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onDidScroll(() => {
        // collapse the back label once content scrolls under the bar; expand at the top
        const y: number = this.scroller.currentOffset().yOffset;
        const collapsed: boolean = y > 8;
        if (collapsed !== this.titleCollapsed) {
          this.titleCollapsed = collapsed;
        }
      })
      .width('100%')
      .layoutWeight(1)
    }
    .id('screen_libraries')
    .width('100%')
    .height('100%')
    // systemGroupedBackground inside the About page sheet (elevated dark)
    .backgroundColor('#1C1C1E')
  }
}
