// file: .ts - pure logic. Port of SwiftRadio/Config/InfoSection.swift.
// Text fields hold a string resource NAME (resources/base/element/string.json) or a literal;
// resolve either with resolveText() from model/Config.ts.
import { bundleManager } from '@kit.AbilityKit';

export class FeatureItem {
  title: string;
  subtitle: string;
  icon: string; // SF Symbol name

  constructor(title: string, subtitle: string, icon: string) {
    this.title = title;
    this.subtitle = subtitle;
    this.icon = icon;
  }
}

// One HarmonyOS SDK kit the app imports: name, "import: modules used" + licence, source link.
export class LibraryItem {
  name: string;
  detail: string;
  url: string;

  constructor(name: string, detail: string, url: string) {
    this.name = name;
    this.detail = detail;
    this.url = url;
  }
}

export enum InfoItemKind {
  // Navigation (pushes to a screen)
  FEATURES = 'features',
  LIBRARIES = 'libraries',
  CREDITS = 'credits',
  // External actions
  LINK = 'link',
  EMAIL = 'email',
  RATE_APP = 'rateApp',
  SHARE = 'share',
  // Display only
  VERSION = 'version'
}

// Swift enum with associated values -> one discriminated class.
export class InfoItem {
  kind: InfoItemKind;
  title: string;
  customSubtitle?: string;
  customIcon?: string;
  url?: string;      // LINK
  address?: string;  // EMAIL
  appID?: string;    // RATE_APP
  text?: string;     // SHARE
  owner?: string;    // CREDITS
  repo?: string;     // CREDITS

  constructor(kind: InfoItemKind, title: string) {
    this.kind = kind;
    this.title = title;
  }

  static features(title: string = 'Features', icon?: string): InfoItem {
    const i: InfoItem = new InfoItem(InfoItemKind.FEATURES, title);
    i.customIcon = icon;
    return i;
  }

  static libraries(title: string = 'Open Source Libraries', subtitle?: string, icon?: string): InfoItem {
    const i: InfoItem = new InfoItem(InfoItemKind.LIBRARIES, title);
    i.customSubtitle = subtitle;
    i.customIcon = icon;
    return i;
  }

  static credits(title: string, subtitle: string | undefined, owner: string, repo: string, icon?: string): InfoItem {
    const i: InfoItem = new InfoItem(InfoItemKind.CREDITS, title);
    i.customSubtitle = subtitle;
    i.owner = owner;
    i.repo = repo;
    i.customIcon = icon;
    return i;
  }

  static link(title: string, subtitle: string | undefined, url: string, icon?: string): InfoItem {
    const i: InfoItem = new InfoItem(InfoItemKind.LINK, title);
    i.customSubtitle = subtitle;
    i.url = url;
    i.customIcon = icon;
    return i;
  }

  static email(title: string, address: string, subtitle?: string, icon?: string): InfoItem {
    const i: InfoItem = new InfoItem(InfoItemKind.EMAIL, title);
    i.customSubtitle = subtitle;
    i.address = address;
    i.customIcon = icon;
    return i;
  }

  static rateApp(title: string, appID: string, icon?: string): InfoItem {
    const i: InfoItem = new InfoItem(InfoItemKind.RATE_APP, title);
    i.appID = appID;
    i.customIcon = icon;
    return i;
  }

  static share(title: string, text: string, icon?: string): InfoItem {
    const i: InfoItem = new InfoItem(InfoItemKind.SHARE, title);
    i.text = text;
    i.customIcon = icon;
    return i;
  }

  static version(title: string = 'App Version', icon?: string): InfoItem {
    const i: InfoItem = new InfoItem(InfoItemKind.VERSION, title);
    i.customIcon = icon;
    return i;
  }

  get subtitle(): string | undefined {
    switch (this.kind) {
      case InfoItemKind.LIBRARIES:
      case InfoItemKind.CREDITS:
      case InfoItemKind.LINK:
        return this.customSubtitle;
      case InfoItemKind.EMAIL:
        return this.customSubtitle !== undefined ? this.customSubtitle : this.address;
      case InfoItemKind.VERSION:
        return InfoItem.versionString();
      default:
        return undefined;
    }
  }

  get icon(): string {
    return this.customIcon !== undefined ? this.customIcon : this.defaultIcon;
  }

  private get defaultIcon(): string {
    switch (this.kind) {
      case InfoItemKind.FEATURES: return 'list.bullet';
      case InfoItemKind.LIBRARIES: return 'book';
      case InfoItemKind.CREDITS: return 'heart';
      case InfoItemKind.LINK: return 'globe';
      case InfoItemKind.EMAIL: return 'envelope';
      case InfoItemKind.RATE_APP: return 'star';
      case InfoItemKind.SHARE: return 'square.and.arrow.up';
      default: return 'info';
    }
  }

  // versionName, as HarmonyOS Settings > Apps shows it (not iOS "short (build)").
  private static versionString(): string {
    try {
      const info: bundleManager.BundleInfo =
        bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      return info.versionName;
    } catch (e) {
      return '';
    }
  }
}

export class InfoSection {
  title: string;
  items: InfoItem[];
  isEnabled: boolean;

  constructor(title: string, items: InfoItem[], isEnabled: boolean = true) {
    this.title = title;
    this.items = items;
    this.isEnabled = isEnabled;
  }
}
