import { router } from '@kit.ArkUI';
import { Features, resolveText } from '../model/Config';
import { FeatureItem } from '../model/InfoSection';

// screen_features: source FeaturesViewController (insetGrouped table), pushed from About.
// Rows are display-only (selectionStyle none, no didSelectRowAt): icon, bold title, subtitle.
// Back pops to About.
@Entry
@Component
struct FeaturesPage {
  private items: FeatureItem[] = Features.ITEMS;

  // FeatureItem.icon (SF Symbol name) -> the nearest HarmonyOS system symbol. The Swift logo
  // is Apple's mark, so that row shows a neutral code glyph.
  private featureSymbol(icon: string): Resource {
    if (icon === 'music.note.list') {
      return $r('sys.symbol.music_note_list');
    } else if (icon === 'checkmark.seal.fill') {
      return $r('sys.symbol.checkmark_circle_fill');
    } else if (icon === 'lock.circle') {
      return $r('sys.symbol.lock');
    } else if (icon === 'paintbrush') {
      return $r('sys.symbol.paintbrush');
    } else if (icon === 'swift') {
      return $r('sys.symbol.code_1');
    }
    return $r('sys.symbol.radio');
  }

  // FeatureItem.icon -> a stable component id for each row's icon (the source's accessibility
  // label for that SF Symbol), so UI tests can address it.
  private iconSlug(icon: string): string {
    if (icon === 'paintbrush') {
      return 'format';
    } else if (icon === 'music.note.list') {
      return 'playlist';
    } else if (icon === 'lock.circle') {
      return 'lock';
    } else if (icon === 'radio') {
      return 'radio';
    } else if (icon === 'checkmark.seal.fill') {
      return 'verified';
    }
    return icon; // 'swift'
  }

  // insetGrouped section: only the first and last cells carry the card's rounded corners
  private rowRadius(index: number): BorderRadiuses {
    const top: number = index === 0 ? 10 : 0;
    const bottom: number = index === this.items.length - 1 ? 10 : 0;
    const r: BorderRadiuses = { topLeft: top, topRight: top, bottomLeft: bottom, bottomRight: bottom };
    return r;
  }

  build() {
    Column() {
      // Navigation bar: back button (chevron + "Back") and the inline centred title
      Stack() {
        Text($r('app.string.features_title'))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
        Row() {
          Button({ type: ButtonType.Normal }) {
            Row({ space: 4 }) {
              SymbolGlyph($r('sys.symbol.chevron_left'))
                .fontSize(22)
                .fontColor(['#FFFFFF'])
              // captured back item reads "Back" (the long previous title collapses to it)
              Text('Back')
                .fontSize(17)
                .fontColor('#FFFFFF')
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

      List() {
        ForEach(this.items, (item: FeatureItem, index: number) => {
          ListItem() {
            Row() {
              // content.image = UIImage(systemName: feature.icon), tint .label
              Row() {
                SymbolGlyph(this.featureSymbol(item.icon))
                  .fontSize(24)
                  .fontColor(['#FFFFFF'])
                  .id(this.iconSlug(item.icon))
              }
              .width(60)
              .justifyContent(FlexAlign.Center)

              Column({ space: 4 }) {
                // bold 17 title, 15pt secondaryLabel subtitle, both unlimited lines
                Text(resolveText(getContext(this), item.title))
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFFFFF')
                Text(resolveText(getContext(this), item.subtitle))
                  .fontSize(15)
                  .fontColor('#99EBEBF5')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              .padding({ top: 11, bottom: 11, right: 16 })
            }
            .width('100%')
          }
          .backgroundColor('#2C2C2E')
          .borderRadius(this.rowRadius(index))
        }, (item: FeatureItem) => item.title)
      }
      // heightForHeaderInSection 20 above the inset-grouped section, 20pt side insets
      .padding({ left: 20, right: 20, top: 24, bottom: 20 })
      .divider({ strokeWidth: 0.5, color: '#545458', startMargin: 60, endMargin: 0 })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .layoutWeight(1)
    }
    .id('screen_features')
    .width('100%')
    .height('100%')
    // systemGroupedBackground inside the About page sheet (elevated dark)
    .backgroundColor('#1C1C1E')
  }
}
