// file: .ts - pure logic. Port of SwiftRadio/Config/Config.swift.
// User-visible text is localized string resources (Content.swift -> string.json), so the
// item tables below carry resource NAMES; resolveText() turns a name (or a literal) into text.
import { common } from '@kit.AbilityKit';
import { FeatureItem, InfoItem, InfoSection, LibraryItem } from './InfoSection';

// Bundle.main.appName (CFBundleDisplayName).
export const APP_NAME: string = 'Swift Radio';

export class Config {
  static readonly DEBUG_LOG: boolean = true;

  // Tint color used across the app (navigation bar, controls, etc.)
  static readonly TINT_COLOR: string = '#FFFFFF';

  // Gradient background color (independent from tintColor)
  static readonly GRADIENT_COLOR: string = '#FFFFFF';

  // true: read the bundled rawfile stations.json; false: GET STATIONS_URL.
  static readonly USE_LOCAL_STATIONS: boolean = true;
  static readonly STATIONS_URL: string = 'https://fethica.com/assets/swift-radio/stations.json';

  // Set this to true to enable the search bar
  static readonly SEARCHABLE: boolean = true;

  // Set this to false to show the next/previous player buttons
  static readonly HIDE_NEXT_PREVIOUS_BUTTONS: boolean = false;

  // Contact & links. Problems with this unofficial port go to its own issue tracker, not to the
  // upstream authors, so the source's contact e-mail row became a "Report an Issue" link.
  static readonly WEBSITE: string = 'https://github.com/analogcode/Swift-Radio-Pro';
  static readonly EMAIL_SUBJECT: string = `From ${APP_NAME} App`;
  static readonly REPORT_ISSUE_URL: string = 'https://github.com/etspworks/SwiftRadio-HarmonyOS/issues/new';
  static readonly FEEDBACK_URL: string = 'https://github.com/etspworks/SwiftRadio-HarmonyOS/issues';
  static readonly LICENSE_URL: string =
    'https://raw.githubusercontent.com/analogcode/Swift-Radio-Pro/refs/heads/master/LICENSE';
}

// The app has no third-party package: it is built on the HarmonyOS SDK kits it imports. The SDK's
// OpenHarmony part declares those kits under Apache License 2.0; Share Kit is in its HMS part.
export class Libraries {
  private static readonly OPENHARMONY_SOURCE: string = 'https://gitee.com/openharmony/interface_sdk-js';
  private static readonly HARMONYOS_REFERENCE: string =
    'https://developer.huawei.com/consumer/en/doc/harmonyos-references-V5/development-intro-api-V5';

  private static openHarmonyKit(name: string, uses: string): LibraryItem {
    return new LibraryItem(name, `${uses}\nApache License 2.0 (OpenHarmony)`, Libraries.OPENHARMONY_SOURCE);
  }

  static readonly ITEMS: LibraryItem[] = [
    Libraries.openHarmonyKit('Ability Kit', '@kit.AbilityKit: UIAbility, bundleManager, wantAgent'),
    Libraries.openHarmonyKit('ArkData', '@kit.ArkData: uniformTypeDescriptor'),
    Libraries.openHarmonyKit('ArkGraphics 2D', '@kit.ArkGraphics2D: drawing'),
    Libraries.openHarmonyKit('ArkTS', '@kit.ArkTS: util'),
    Libraries.openHarmonyKit('ArkUI', '@kit.ArkUI: router, window, promptAction, curves'),
    Libraries.openHarmonyKit('ArkWeb', '@kit.ArkWeb: webview'),
    Libraries.openHarmonyKit('Audio Kit', '@kit.AudioKit: audio'),
    Libraries.openHarmonyKit('AVSession Kit', '@kit.AVSessionKit: avSession, AVCastPicker'),
    Libraries.openHarmonyKit('Background Tasks Kit', '@kit.BackgroundTasksKit: backgroundTaskManager'),
    Libraries.openHarmonyKit('Basic Services Kit', '@kit.BasicServicesKit: pasteboard'),
    Libraries.openHarmonyKit('Core File Kit', '@kit.CoreFileKit: fileIo, fileUri, BackupExtensionAbility'),
    Libraries.openHarmonyKit('Image Kit', '@kit.ImageKit: image'),
    Libraries.openHarmonyKit('Media Kit', '@kit.MediaKit: media (AVPlayer)'),
    Libraries.openHarmonyKit('Network Kit', '@kit.NetworkKit: http'),
    Libraries.openHarmonyKit('Performance Analysis Kit', '@kit.PerformanceAnalysisKit: hilog'),
    new LibraryItem('Share Kit', '@kit.ShareKit: systemShare\nHarmonyOS SDK, closed source',
      Libraries.HARMONYOS_REFERENCE)
  ];
}

export class Features {
  static readonly ITEMS: FeatureItem[] = [
    new FeatureItem('features_arktsCodebase_title', 'features_arktsCodebase_description', 'swift'),
    new FeatureItem('features_customizableUI_title', 'features_customizableUI_description', 'paintbrush'),
    new FeatureItem('features_albumArt_title', 'features_albumArt_description', 'music.note.list'),
    new FeatureItem('features_lockScreen_title', 'features_lockScreen_description', 'lock.circle'),
    new FeatureItem('features_multipleStations_title', 'features_multipleStations_description', 'radio'),
    new FeatureItem('features_easySetup_title', 'features_easySetup_description', 'checkmark.seal.fill')
  ];
}

export class About {
  // Swift source (InfoSection.swift) never overrides isEnabled at a call site, so every
  // section defaults to enabled: true (Config.swift's About.sections literal).
  private static buildSection(title: string, items: InfoItem[]): InfoSection {
    const section: InfoSection = new InfoSection(title, items, true);
    section.title = title;
    section.isEnabled = true;
    return section;
  }

  static readonly SECTIONS: InfoSection[] = [
    About.buildSection('about_sections_features', [
      InfoItem.features('about_items_features')
    ]),
    About.buildSection('about_sections_contact', [
      InfoItem.link('about_items_reportIssue', 'about_reportIssue_message', Config.REPORT_ISSUE_URL,
        'exclamationmark.bubble'),
      InfoItem.link('about_feedback_title', 'about_feedback_message', Config.FEEDBACK_URL)
    ]),
    About.buildSection('about_sections_support', [
      InfoItem.rateApp('about_items_rateApp', 'YOUR_APP_ID'),
      InfoItem.share('about_items_shareApp', 'about_shareText')
    ]),
    About.buildSection('about_sections_credits', [
      InfoItem.libraries('about_items_libraries'),
      InfoItem.credits('about_items_contributors', 'about_items_specialThanks', 'analogcode', 'Swift-Radio-Pro')
    ]),
    About.buildSection('about_sections_legal', [
      InfoItem.link('about_license_title', 'about_license_detail', Config.LICENSE_URL)
    ]),
    About.buildSection('about_sections_version', [
      InfoItem.version('about_items_appVersion')
    ])
  ];
}

// A string resource name resolves to its localized value; anything else (an address, a version
// string, a source default literal) is returned unchanged.
export function resolveText(context: common.Context, nameOrText: string | undefined): string {
  if (nameOrText === undefined) {
    return '';
  }
  try {
    return context.resourceManager.getStringByNameSync(nameOrText);
  } catch (e) {
    return nameOrText;
  }
}
