import { router } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { StationsManager } from '../common/StationsManager';
import { NetworkService } from '../common/NetworkService';
import { describeError } from '../common/ErrorText';
import { GradientBackground } from '../components/GradientBackground';

// screen_loader: source LoaderController — fetch stations, then swap the root to the
// stations list (MainCoordinator.didFinishLoading setViewControllers => replaceUrl).
@Entry
@Component
struct LoaderSplashStationsFetchPage {
  @State isLoading: boolean = true;
  @State error: string | null = null;

  aboutToAppear(): void {
    this.fetchStations();
  }

  private async fetchStations(): Promise<void> {
    this.error = null;
    this.isLoading = true;
    try {
      // The stations are bundled and load offline, so the launch asks for a network itself.
      if (!(await NetworkService.isOnline())) {
        throw new Error('No internet connection. Connect to Wi-Fi or mobile data and try again.');
      }
      await StationsManager.shared.fetch(getContext(this));
      router.replaceUrl({ url: 'pages/StationsListPage' });
    } catch (e) {
      this.isLoading = false;
      this.error = describeError(e as BusinessError);
    }
  }

  build() {
    Stack() {
      // BaseController.setupViews: full-bleed gradient background
      GradientBackground()

      // The logo is centred on the screen; the spinner / error stack hang 32pt below it.
      // Equal-height spacer above and below keeps the logo at the exact centre.
      Column() {
        Column()
          .width('100%')
          .height(220)
        // logoImageView: 220x220, centered
        Image($r('app.media.logo'))
          .width(220)
          .height(220)
          .objectFit(ImageFit.Contain)
        Column() {
          // activityIndicatorView (.medium): animating while StationsManager.fetch is in flight
          if (this.isLoading) {
            LoadingProgress()
              .width(32)
              .height(32)
              .color('#99EBEBF5')
          } else if (this.error !== null) {
            // stackView (hidden while loading): errorTitleLabel, errorMessageLabel, retryButton
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
              // UIButton(type: .system): plain tinted title, default system blue
              Button($r('app.string.loader_retryButton'), { type: ButtonType.Normal })
                .fontSize(17)
                .fontColor('#0A84FF')
                .backgroundColor(Color.Transparent)
                .height(44)
                .id('loader_retry')
                .accessibilityText('Try again') // = app.string.loader_retryButton (only locale: en_US)
                .onClick(() => {
                  this.fetchStations();
                })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          }
        }
        .width('70%')
        .height(220)
        .padding({ top: 32 })
        .justifyContent(FlexAlign.Start)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .id('screen_loader')
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
  }
}
