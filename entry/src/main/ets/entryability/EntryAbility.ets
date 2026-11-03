import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AudioSetupService } from '../common/AudioSetupService';

const DOMAIN = 0x0000;
const LAUNCH_PAGE: string = 'pages/LoaderSplashStationsFetchPage';
// AppStorage key: an overlay the deep link asks the host page to present on first show.
export const KEY_PENDING_OVERLAY: string = 'pendingOverlay';
// AppStorage key: a page the host pushes over itself once it is up (the source only ever
// reaches it by a push, so Back must return to the host).
export const KEY_PENDING_PUSH: string = 'pendingPush';

class DeepLinkTarget {
  url: string;
  overlay: string;
  push: string;

  constructor(url: string, overlay: string, push: string) {
    this.url = url;
    this.overlay = overlay;
    this.push = push;
  }
}

// Every spelling the replay / tooling may pass as want.parameters.targetPage: the plan screen
// id, the route url / page name, and the source view-controller name of the capture.
// Overlay screens (About, Now Playing, options sheet) open their host page plus the overlay.
function resolveTarget(raw: string): DeepLinkTarget | undefined {
  const key: string = raw.toLowerCase().replace(new RegExp('[^a-z0-9]', 'g'), '').replace(new RegExp('page$'), '');
  const table: Map<string, DeepLinkTarget> = new Map<string, DeepLinkTarget>();
  const stations: string = 'pages/StationsListPage';
  const add = (names: string[], url: string, overlay: string, push: string = ''): void => {
    for (const n of names) {
      table.set(n, new DeepLinkTarget(url, overlay, push));
    }
  };
  add(['screenloader', 'loadersplashstationsfetch', 'loadercontroller', 'loader'], LAUNCH_PAGE, '');
  add(['screenstations', 'stationslist', 'stationsviewcontroller', 'stations'], stations, '');
  add(['screenabout', 'aboutswiftradio', 'aboutviewcontroller', 'about'], stations, 'about');
  add(['screennowplaying', 'nowplayingplayer', 'nowplayingviewcontroller', 'nowplaying'], stations, 'now_playing');
  add(['screenbottomsheet', 'nowplayingoptionssheet', 'bottomsheetviewcontroller', 'bottomsheet'], stations, 'bottom_sheet');
  // AboutCoordinator pushes these inside the About sheet: Stations + About sheet, then the page.
  add(['screencontributors', 'contributors', 'contributorsviewcontroller'], stations, 'about', 'pages/ContributorsPage');
  add(['screenfeatures', 'features', 'featuresviewcontroller'], stations, 'about', 'pages/FeaturesPage');
  add(['screenlibraries', 'opensourcelibraries', 'librariesviewcontroller', 'libraries'], stations, 'about',
    'pages/OpenSourceLibrariesPage');
  // MainCoordinator.didSelectBottomSheetOption(.info) pushes it on the main stack over Stations.
  add(['screeninfodetail', 'aboutstationstationdetail', 'infodetailviewcontroller', 'infodetail'], stations, '',
    'pages/AboutStationStationDetailPage');
  return table.get(key);
}

function readTargetPage(want: Want): string {
  const params: Record<string, Object> | undefined = want.parameters as Record<string, Object> | undefined;
  if (params === undefined) {
    return '';
  }
  const v: Object | undefined = params['targetPage'];
  return typeof v === 'string' ? v : '';
}

export default class EntryAbility extends UIAbility {
  private windowStage?: window.WindowStage;
  private pendingTarget: string = '';

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    this.pendingTarget = readTargetPage(want);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.pendingTarget = readTargetPage(want);
    this.routePending();
  }

  onDestroy(): void {
    AudioSetupService.shared.teardown().catch((e: Error) => {
      hilog.error(DOMAIN, 'testTag', 'AudioSetupService.teardown failed: %{public}s', e.message);
    });
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    this.windowStage = windowStage;
    const target: DeepLinkTarget | undefined = resolveTarget(this.pendingTarget);
    // A deep link loads its page directly; otherwise the loader is the entry page.
    const page: string = target !== undefined ? target.url : LAUNCH_PAGE;
    if (target !== undefined) {
      AppStorage.setOrCreate<string>(KEY_PENDING_OVERLAY, target.overlay);
      AppStorage.setOrCreate<string>(KEY_PENDING_PUSH, target.push);
      this.pendingTarget = '';
    }
    windowStage.loadContent(page, (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      // Audio setup creates the player singletons, which publish to AppStorage: run it only once a
      // UI instance exists, never during onCreate.
      AudioSetupService.shared.setup(this.context).catch((e: Error) => {
        hilog.error(DOMAIN, 'testTag', 'AudioSetupService.setup failed: %{public}s', e.message);
      });
    });
  }

  // onNewWant on a running (singleton) ability: route the already-loaded window.
  private routePending(): void {
    const target: DeepLinkTarget | undefined = resolveTarget(this.pendingTarget);
    if (target === undefined || this.windowStage === undefined) {
      return;
    }
    this.pendingTarget = '';
    AppStorage.setOrCreate<string>(KEY_PENDING_OVERLAY, target.overlay);
    AppStorage.setOrCreate<string>(KEY_PENDING_PUSH, target.push);
    try {
      const router = this.windowStage.getMainWindowSync().getUIContext().getRouter();
      router.clear();
      router.replaceUrl({ url: target.url }).catch((e: Error) => {
        hilog.error(DOMAIN, 'testTag', 'deep-link route failed: %{public}s', e.message);
      });
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'deep-link route failed: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
