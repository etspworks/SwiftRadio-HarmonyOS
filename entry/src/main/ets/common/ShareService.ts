// file: .ts - pure logic. Ports of ShareActivity (SwiftRadio/Helpers/ShareActivity.swift) and
// BottomSheetHandler (SwiftRadio/Helpers/BottomSheetHandler.swift).
// Share sheet -> @kit.ShareKit systemShare (SharedData + ShareController); on any failure the
// text goes to the pasteboard with a toast, so a share tap is never a silent no-op.
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BottomSheetOption, BottomSheetOptionKind } from '../model/BottomSheetOption';
import { RadioStation } from '../model/RadioStation';
import { LinkOpener } from './LinkOpener';

const DOMAIN: number = 0x0001;
const TAG: string = 'ShareService';

// What BottomSheetHandler needs from the presenting screen: a context and the in-app push to
// the station info page (navigation is a UI concern).
export interface BottomSheetHost {
  context: common.UIAbilityContext;
  showStationInfo: (station: RadioStation) => void;
}

async function copyFallback(text: string): Promise<void> {
  try {
    const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    await pasteboard.getSystemPasteboard().setData(data);
    promptAction.showToast({ message: 'Copied to clipboard' });
  } catch (e) {
    const err: BusinessError = e as BusinessError;
    hilog.error(DOMAIN, TAG, 'clipboard fallback failed: %{public}s', err.message);
    promptAction.showToast({ message: 'Sharing is not available' });
  }
}

async function present(context: common.UIAbilityContext, data: systemShare.SharedData, fallbackText: string,
  onDismiss?: () => void): Promise<boolean> {
  try {
    const controller: systemShare.ShareController = new systemShare.ShareController(data);
    const completionWithItemsHandler = (): void => {
      hilog.info(DOMAIN, TAG, 'share panel dismissed');
      if (onDismiss !== undefined) {
        onDismiss();
      }
    };
    controller.on('dismiss', completionWithItemsHandler);
    await controller.show(context, { previewMode: systemShare.SharePreviewMode.DETAIL });
    return true;
  } catch (e) {
    const err: BusinessError = e as BusinessError;
    hilog.warn(DOMAIN, TAG, 'share panel failed: %{public}d %{public}s', err.code, err.message);
    await copyFallback(fallbackText);
    return false;
  }
}

export class ShareService {

  // ShareActivity.activityController: shares station.shoutout + the rendered share card.
  // `shareImage` is the LogoShareView card the UI rendered (componentSnapshot); without one the
  // shoutout text is shared alone.
  static async activityController(context: common.UIAbilityContext, shareImage: image.PixelMap | undefined,
    station: RadioStation, completion?: () => void): Promise<boolean> {
    const text: systemShare.SharedRecord = {
      utd: utd.UniformDataType.PLAIN_TEXT,
      content: station.shoutout,
      title: station.name
    };
    // The share panel previews the first record: the card goes first, the shoutout rides along.
    const uri: string | undefined = await ShareService.generateImage(context, shareImage, station);
    if (uri === undefined) {
      return present(context, new systemShare.SharedData(text), station.shoutout, completion);
    }
    const data: systemShare.SharedData = new systemShare.SharedData({
      utd: utd.UniformDataType.PNG,
      uri: uri,
      title: station.name
    });
    data.addRecord(text);
    return present(context, data, station.shoutout, completion);
  }

  // 'Share the App' (InfoItem.share text).
  static async shareText(context: common.UIAbilityContext, text: string): Promise<boolean> {
    const data: systemShare.SharedData = new systemShare.SharedData({
      utd: utd.UniformDataType.PLAIN_TEXT,
      content: text
    });
    return present(context, data, text);
  }

  // Source renders LogoShareView to a UIImage; here the UI hands over its snapshot PixelMap and
  // this writes it as a PNG into the sandbox cache, returning a shareable file URI.
  private static async generateImage(context: common.UIAbilityContext, shareImage: image.PixelMap | undefined,
    station: RadioStation): Promise<string | undefined> {
    if (shareImage === undefined) {
      return undefined;
    }
    const packer: image.ImagePacker = image.createImagePacker();
    try {
      const buffer: ArrayBuffer = await packer.packing(shareImage, { format: 'image/png', quality: 100 });
      const safe: string = station.name.replace(new RegExp('[^A-Za-z0-9]', 'g'), '_');
      const path: string = `${context.cacheDir}/share_${safe}.png`;
      const file: fileIo.File = fileIo.openSync(path,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, buffer);
      } finally {
        fileIo.closeSync(file);
      }
      return fileUri.getUriFromPath(path);
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.warn(DOMAIN, TAG, 'share image failed: %{public}s', err.message);
      return undefined;
    } finally {
      packer.release();
    }
  }

  // BottomSheetHandler.handle
  static async handle(option: BottomSheetOption, station: RadioStation, host: BottomSheetHost): Promise<void> {
    switch (option.kind) {
      case BottomSheetOptionKind.INFO:
        host.showStationInfo(station);
        break;
      case BottomSheetOptionKind.SHARE:
        await ShareService.activityController(host.context, option.shareImage, station);
        break;
      case BottomSheetOptionKind.WEBSITE:
        if (station.website !== undefined) {
          await LinkOpener.open(host.context, station.website);
        }
        break;
      case BottomSheetOptionKind.OPEN_IN_MUSIC:
        if (option.url !== undefined) {
          await LinkOpener.openExternal(host.context, option.url);
        }
        break;
      default:
        break;
    }
  }
}
