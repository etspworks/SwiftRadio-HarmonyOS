// file: .ts - pure logic. SFSafariViewController -> the in-app pages/InAppBrowserPage (ArkWeb);
// UIApplication.open / MFMailComposeViewController -> Want-based startAbility (external app).
// Every method resolves false on failure so the caller can show its alert
// (e.g. 'Could Not Send Email') - never a silent no-op.
import { common, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Config } from '../model/Config';

const DOMAIN: number = 0x0001;
const TAG: string = 'LinkOpener';

// Mirrors InAppBrowserParams in pages/InAppBrowserPage.ets (.ts cannot import .ets).
interface InAppBrowserParams {
  url: string;
}

async function start(context: common.UIAbilityContext, want: Want): Promise<boolean> {
  try {
    await context.startAbility(want);
    return true;
  } catch (e) {
    const err: BusinessError = e as BusinessError;
    hilog.warn(DOMAIN, TAG, 'startAbility %{public}s failed: %{public}d %{public}s',
      want.uri ?? '', err.code, err.message);
    return false;
  }
}

export class LinkOpener {
  // SFSafariViewController(url): in-app browser page over the app. Falls back to the system
  // browser only when the push fails.
  static async open(context: common.UIAbilityContext, url: string | undefined): Promise<boolean> {
    if (url === undefined || url.length === 0) {
      return false;
    }
    try {
      const params: InAppBrowserParams = { url: url };
      await router.pushUrl({ url: 'pages/InAppBrowserPage', params: params });
      return true;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.warn(DOMAIN, TAG, 'in-app browser push failed: %{public}d %{public}s', err.code, err.message);
      return LinkOpener.openExternal(context, url);
    }
  }

  // UIApplication.shared.open(url): hand the URL to the system (leaves the app).
  static async openExternal(context: common.UIAbilityContext, url: string | undefined): Promise<boolean> {
    if (url === undefined || url.length === 0) {
      return false;
    }
    const want: Want = {
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: url
    };
    return start(context, want);
  }

  // MFMailComposeViewController -> mailto: in the mail app.
  static async sendEmail(context: common.UIAbilityContext, address: string,
    subject: string = Config.EMAIL_SUBJECT): Promise<boolean> {
    const uri: string = `mailto:${address}?subject=${encodeURIComponent(subject)}`;
    const send: Want = { action: 'ohos.want.action.sendToData', uri: uri };
    if (await start(context, send)) {
      return true;
    }
    const view: Want = { action: 'ohos.want.action.viewData', uri: uri };
    return start(context, view);
  }


  static htmlURL(owner: string, repo?: string): string {
    return repo !== undefined ? `https://github.com/${owner}/${repo}` : `https://github.com/${owner}`;
  }
}
