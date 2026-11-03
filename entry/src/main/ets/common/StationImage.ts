// file: .ts - pure logic. Port of RadioStation.getImage (SwiftRadio/Model/RadioStation.swift:56).
// The source returns a UIImage via callback; ArkUI Image() loads network URLs and media
// resources itself, so the port returns WHAT to load: a remote URL (with the bundled
// fallback for .alt()/onError) or the bundled media resource name.

export interface StationImageRef {
  remoteUrl?: string;
  mediaName: string;
}

// Source fallback: UIImage(named: "stationImage").
export const FALLBACK_MEDIA_NAME: string = 'stationImage';

// Bundled station art under resources/base/media. stations.json names use '-',
// resource names cannot, so the assets pass stored them with '_'.
// Note: fixed list mirrors resources/base/media; add a name here when station art is added.
const BUNDLED_MEDIA: string[] = [
  'station_absolutecountry',
  'az_rock_radio',
  'station_therockfm',
  'station_radio1190',
  'stationImage'
];

export function resolveStationImage(imageURL: string): StationImageRef {
  if (imageURL.includes('http')) {
    const remote: StationImageRef = { remoteUrl: imageURL, mediaName: FALLBACK_MEDIA_NAME };
    return remote;
  }
  // UIImage(named:) misses on an empty or unknown name -> fallback image.
  const name: string = imageURL.replace(new RegExp('-', 'g'), '_');
  const local: StationImageRef = {
    mediaName: BUNDLED_MEDIA.indexOf(name) >= 0 ? name : FALLBACK_MEDIA_NAME
  };
  return local;
}
