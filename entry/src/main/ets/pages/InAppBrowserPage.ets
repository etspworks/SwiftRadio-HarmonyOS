import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';

export class InAppBrowserParams {
  url: string = '';
}

// feat_in_app_browser: port of SFSafariViewController(url), which the source presents over the
// app (ContributorsViewController, LibrariesViewController, AboutCoordinator .link,
// MainCoordinator, InfoDetailViewController, BottomSheetHandler .website). The page keeps the
// app in the foreground; Done pops back to the presenting screen.
@Entry
@Component
struct InAppBrowserPage {
  @State url: string = '';
  @State pageTitle: string = '';
  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    const p: InAppBrowserParams | undefined = router.getParams() as InAppBrowserParams | undefined;
    if (p !== undefined && p.url !== undefined) {
      this.url = p.url;
    }
  }

  private host(): string {
    const m: RegExpMatchArray | null = this.url.match(new RegExp('^[a-zA-Z]+://([^/?#]+)'));
    return m !== null && m.length > 1 ? m[1] : this.url;
  }

  build() {
    Column() {
      Row() {
        // Platform controller chrome: SFSafariViewController's own 'Done' dismiss button,
        // not a control declared by the source app.
        Button('Done', { type: ButtonType.Normal })
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(Color.Transparent)
          .height(44)
          .id('inapp_browser_done')
          .onClick(() => {
            router.back();
          })
        Column() {
          Text(this.pageTitle.length > 0 ? this.pageTitle : this.host())
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.host())
            .fontSize(12)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .padding({ right: 64 })
      }
      .width('100%')
      .height(52)

      if (this.url.length > 0) {
        Web({ src: this.url, controller: this.controller })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .onTitleReceive((event: OnTitleReceiveEvent) => {
            this.pageTitle = event.title;
          })
          .width('100%')
          .layoutWeight(1)
      }
    }
    .id('InAppBrowserPage')
    .width('100%')
    .height('100%')
  }
}
