// file: .ts - pure logic. Port of SwiftRadio/Model/RadioStation.swift (Codable struct + extensions).
import { RadioPlayer } from '../common/RadioPlayer';
import { resolveStationImage, StationImageRef } from '../common/StationImage';
import { APP_NAME } from './Config';

// Wire shape of one stations.json entry.
export interface RadioStationJson {
  name: string;
  website?: string;
  streamURL: string;
  imageURL: string;
  desc: string;
  longDesc?: string;
}

// JSON root {"station": [...]} - the source decodes [String: [RadioStation]] inline.
export interface StationsResponse {
  station?: RadioStationJson[];
}

export class RadioStation {
  name: string = '';
  website?: string;
  streamURL: string = '';
  imageURL: string = '';
  desc: string = '';
  longDesc: string = '';

  static fromJson(j: RadioStationJson): RadioStation {
    const s: RadioStation = new RadioStation();
    s.name = j.name;
    s.website = j.website;
    s.streamURL = j.streamURL;
    s.imageURL = j.imageURL;
    s.desc = j.desc;
    s.longDesc = j.longDesc !== undefined ? j.longDesc : '';
    return s;
  }

  get hasValidWebsite(): boolean {
    const w: string | undefined = this.website;
    if (w === undefined || w.length === 0) {
      return false;
    }
    const m: RegExpMatchArray | null = w.match(new RegExp('^([a-zA-Z][a-zA-Z0-9+.-]*):'));
    return m !== null && m[1].startsWith('http');
  }

  get shoutout(): string {
    return `I'm listening to ${this.name} via ${APP_NAME} app`;
  }

  // Source ==: name, streamURL, imageURL, desc, longDesc (website is deliberately not compared).
  equals(other: RadioStation | undefined): boolean {
    if (other === undefined) {
      return false;
    }
    return this.name === other.name && this.streamURL === other.streamURL &&
      this.imageURL === other.imageURL && this.desc === other.desc && this.longDesc === other.longDesc;
  }

  // Source getImage(completion:) - ArkUI Image() loads the URL/resource itself, so this returns
  // what to load (remote URL with bundled fallback, or the bundled media name).
  getImage(): StationImageRef {
    return resolveStationImage(this.imageURL);
  }

  get trackName(): string {
    const t: string | undefined = RadioPlayer.shared.currentMetadata?.trackName;
    return t !== undefined ? t : this.name;
  }

  get artistName(): string {
    const a: string | undefined = RadioPlayer.shared.currentMetadata?.artistName;
    return a !== undefined ? a : this.desc;
  }

  get musicSearchURL(): string | undefined {
    const track: string | undefined = RadioPlayer.shared.currentMetadata?.trackName;
    const artist: string | undefined = RadioPlayer.shared.currentMetadata?.artistName;
    if (track === undefined || artist === undefined) {
      return undefined;
    }
    const url: string = `https://music.apple.com/search?term=${encodeURIComponent(track)}+${encodeURIComponent(artist)}`;
    return url.replace(new RegExp('%2B', 'g'), '%20');
  }
}
