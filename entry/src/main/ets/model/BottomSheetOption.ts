// file: .ts - pure logic. Port of BottomSheetViewController.Option
// (SwiftRadio/ViewControllers/BottomSheetViewController.swift:27-50).
import { image } from '@kit.ImageKit';

export enum BottomSheetOptionKind {
  INFO = 'info',
  SHARE = 'share',
  WEBSITE = 'website',
  OPEN_IN_MUSIC = 'openInMusic'
}

export class BottomSheetOption {
  kind: BottomSheetOptionKind;
  // .share(UIImage?) payload: the rendered share card / artwork, when the caller has one.
  shareImage?: image.PixelMap;
  // .openInMusic(URL?) payload.
  url?: string;

  constructor(kind: BottomSheetOptionKind, shareImage?: image.PixelMap, url?: string) {
    this.kind = kind;
    this.shareImage = shareImage;
    this.url = url;
  }

  static info(): BottomSheetOption {
    return new BottomSheetOption(BottomSheetOptionKind.INFO);
  }

  static share(shareImage?: image.PixelMap): BottomSheetOption {
    return new BottomSheetOption(BottomSheetOptionKind.SHARE, shareImage);
  }

  static website(): BottomSheetOption {
    return new BottomSheetOption(BottomSheetOptionKind.WEBSITE);
  }

  // String resource NAME (resources/base/element/string.json) - resolve with resolveText().
  get title(): string {
    switch (this.kind) {
      case BottomSheetOptionKind.INFO: return 'bottomSheet_aboutStation';
      case BottomSheetOptionKind.WEBSITE: return 'bottomSheet_stationWebsite';
      default: return 'bottomSheet_shareNowPlaying';
    }
  }

  // Source SF Symbol name; NowPlayingOptionsSheetPage maps it to a HarmonyOS system symbol.
  get image(): string {
    switch (this.kind) {
      case BottomSheetOptionKind.INFO: return 'info.circle';
      case BottomSheetOptionKind.SHARE: return 'square.and.arrow.up';
      case BottomSheetOptionKind.WEBSITE: return 'safari';
      default: return 'music.note';
    }
  }
}
