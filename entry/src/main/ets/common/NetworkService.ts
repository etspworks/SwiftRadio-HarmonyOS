// file: .ts - pure logic. Port of SwiftRadio/Networking/NetworkService.swift (URLSession -> @ohos.net.http).
import { connection, http } from '@kit.NetworkKit';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Config } from '../model/Config';
import { NetworkError, NetworkErrorKind } from '../model/NetworkError';
import { RadioStation, RadioStationJson, StationsResponse } from '../model/RadioStation';
import { Contributor, ContributorJson, GitHubRepo, GitHubRepoJson } from '../model/GitHub';

const DOMAIN: number = 0x0001;
const TAG: string = 'NetworkService';
const TIMEOUT_MS: number = 20000;

function debugLog(message: string): void {
  if (Config.DEBUG_LOG) {
    hilog.info(DOMAIN, TAG, '%{public}s', message);
  }
}

function isHttpUrl(url: string): boolean {
  return url.startsWith('https://') || url.startsWith('http://');
}

// GitHub rejects requests without a User-Agent (URLSession sends one implicitly).
const GITHUB_HEADERS: Record<string, string> = {
  'User-Agent': 'SwiftRadio',
  'Accept': 'application/vnd.github+json'
};

// One createHttp() per request, destroyed in finally. Non-2xx -> HTTP_RESPONSE_NOT_VALID.
async function getText(url: string, header: Record<string, string>, usingCache: boolean): Promise<string> {
  const req: http.HttpRequest = http.createHttp();
  try {
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      header: header,
      expectDataType: http.HttpDataType.STRING,
      usingCache: usingCache,
      connectTimeout: TIMEOUT_MS,
      readTimeout: TIMEOUT_MS
    };
    const resp: http.HttpResponse = await req.request(url, options);
    if (resp.responseCode < 200 || resp.responseCode > 299) {
      debugLog(`API: HTTP status code has unexpected value ${resp.responseCode} for ${url}`);
      throw new NetworkError(NetworkErrorKind.HTTP_RESPONSE_NOT_VALID, resp.responseCode);
    }
    return resp.result as string;
  } finally {
    req.destroy();
  }
}

async function getBytes(url: string): Promise<ArrayBuffer> {
  const req: http.HttpRequest = http.createHttp();
  try {
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      usingCache: true,
      connectTimeout: TIMEOUT_MS,
      readTimeout: TIMEOUT_MS
    };
    const resp: http.HttpResponse = await req.request(url, options);
    if (resp.responseCode < 200 || resp.responseCode > 299) {
      throw new NetworkError(NetworkErrorKind.HTTP_RESPONSE_NOT_VALID, resp.responseCode);
    }
    return resp.result as ArrayBuffer;
  } finally {
    req.destroy();
  }
}

// URLCache.shared stand-in for decoded images (lock-screen artwork, share card).
// Note: unbounded in-memory map; artwork URLs per session are few. Add an LRU cap if that changes.
const imageCache: Map<string, image.PixelMap> = new Map<string, image.PixelMap>();

export async function decodePixelMap(buffer: ArrayBuffer): Promise<image.PixelMap | undefined> {
  const source: image.ImageSource = image.createImageSource(buffer);
  try {
    return await source.createPixelMap();
  } catch (e) {
    return undefined;
  } finally {
    source.release();
  }
}

export class NetworkService {

  // False with no default data network (Airplane mode, Wi-Fi and mobile data off). A failed
  // check counts as online, so it never blocks the launch.
  static async isOnline(): Promise<boolean> {
    try {
      return await connection.hasDefaultNet();
    } catch (e) {
      return true;
    }
  }

  // MARK: - Stations

  static async fetchStations(context: common.Context): Promise<RadioStation[]> {
    let text: string;

    if (Config.USE_LOCAL_STATIONS) {
      let bytes: Uint8Array;
      try {
        bytes = await context.resourceManager.getRawFileContent('stations.json');
      } catch (e) {
        debugLog('The local JSON file could not be found');
        throw new NetworkError(NetworkErrorKind.FILE_NOT_FOUND);
      }
      text = util.TextDecoder.create('utf-8').decodeToString(bytes);
    } else {
      if (!isHttpUrl(Config.STATIONS_URL)) {
        debugLog('stationsURL not a valid URL');
        throw new NetworkError(NetworkErrorKind.URL_NOT_VALID);
      }
      // .reloadIgnoringLocalCacheData
      const requestCachePolicy: boolean = false;
      text = await getText(Config.STATIONS_URL, {}, requestCachePolicy);
    }

    debugLog('Stations JSON Found');

    let response: StationsResponse;
    try {
      response = JSON.parse(text) as StationsResponse;
    } catch (e) {
      throw new NetworkError(NetworkErrorKind.DATA_NOT_VALID);
    }
    const list: RadioStationJson[] | undefined = response.station;
    if (list === undefined || !Array.isArray(list)) {
      throw new NetworkError(NetworkErrorKind.DATA_NOT_VALID);
    }
    return list.map((j: RadioStationJson): RadioStation => RadioStation.fromJson(j));
  }

  // MARK: - Images

  // List/grid images use ArkUI Image(url) (built-in cache); this is for callers that need a
  // PixelMap (AVSession lock-screen artwork, share card). undefined on any failure, like the source.
  static async fetchImage(url: string): Promise<image.PixelMap | undefined> {
    const cached: image.PixelMap | undefined = imageCache.get(url);
    if (cached !== undefined) {
      return cached;
    }
    try {
      const buffer: ArrayBuffer = await getBytes(url);
      const pm: image.PixelMap | undefined = await decodePixelMap(buffer);
      if (pm !== undefined) {
        imageCache.set(url, pm);
      }
      return pm;
    } catch (e) {
      return undefined;
    }
  }

  // MARK: - GitHub API

  static async fetchContributors(owner: string, repo: string): Promise<Contributor[]> {
    const url: string = `https://api.github.com/repos/${owner}/${repo}/contributors`;
    if (owner.length === 0 || repo.length === 0) {
      throw new NetworkError(NetworkErrorKind.URL_NOT_VALID);
    }
    const text: string = await getText(url, GITHUB_HEADERS, false);
    let list: ContributorJson[];
    try {
      list = JSON.parse(text) as ContributorJson[];
    } catch (e) {
      throw new NetworkError(NetworkErrorKind.DATA_NOT_VALID);
    }
    if (!Array.isArray(list)) {
      throw new NetworkError(NetworkErrorKind.DATA_NOT_VALID);
    }
    return list.map((j: ContributorJson): Contributor => Contributor.fromJson(j));
  }

  static async fetchRepository(owner: string, repo: string): Promise<GitHubRepo> {
    const url: string = `https://api.github.com/repos/${owner}/${repo}`;
    if (owner.length === 0 || repo.length === 0) {
      throw new NetworkError(NetworkErrorKind.URL_NOT_VALID);
    }
    const text: string = await getText(url, GITHUB_HEADERS, false);
    let j: GitHubRepoJson;
    try {
      j = JSON.parse(text) as GitHubRepoJson;
    } catch (e) {
      throw new NetworkError(NetworkErrorKind.DATA_NOT_VALID);
    }
    if (j === null || typeof j.name !== 'string') {
      throw new NetworkError(NetworkErrorKind.DATA_NOT_VALID);
    }
    return GitHubRepo.fromJson(j);
  }
}
