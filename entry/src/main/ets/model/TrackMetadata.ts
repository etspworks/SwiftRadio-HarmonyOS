// file: .ts - pure logic. Replaces FRadioPlayer.Metadata + DefaultMetadataExtractor (external SPM
// package FRadioPlayer 0.2.2, read for behaviour only - never ported).

// Source cleanRawMetadataIfNeeded pattern: drops "(...)" and "[...]" groups.
const CLEAN_PATTERN: string = '(\\(.*?\\)\\w*)|(\\[.*?\\]\\w*)';

export class FRadioPlayerMetadata {
  artistName?: string;
  trackName?: string;
  rawValue?: string;

  constructor(artistName?: string, trackName?: string, rawValue?: string) {
    this.artistName = artistName;
    this.trackName = trackName;
    this.rawValue = rawValue;
  }

  get isEmpty(): boolean {
    return this.artistName === undefined && this.trackName === undefined;
  }

  // DefaultMetadataExtractor.extract: clean, split on " - ", artist = first part, track = last part.
  static fromRaw(raw: string | undefined): FRadioPlayerMetadata | undefined {
    if (raw === undefined) {
      return undefined;
    }
    const cleaned: string = raw.replace(new RegExp(CLEAN_PATTERN, 'g'), '');
    const parts: string[] = cleaned.split(' - ');
    const meta: FRadioPlayerMetadata = new FRadioPlayerMetadata();
    meta.artistName = parts[0];
    meta.trackName = parts[parts.length - 1];
    meta.rawValue = cleaned;
    return meta;
  }
}
