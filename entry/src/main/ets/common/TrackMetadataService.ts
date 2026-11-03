// file: .ts - pure logic. Replaces FRadioPlayer's timed-metadata output + iTunesAPI artwork lookup
// (external SPM package FRadioPlayer 0.2.2; behaviour read from its source, never ported).
//
// Substitution (decided here, platform-capability): AVPlayer exposes no ICY/timed-metadata API on
// HarmonyOS. A separate @ohos.net.http requestInStream to the same stream URL with
// 'Icy-MetaData: 1' reads the 'icy-metaint' response header, parses StreamTitle='Artist - Track'
// from the first metadata block, then aborts (destroy) - no second audio download stays open.
// Re-polled every 30 s while playing. Any failure yields undefined, which callers treat as the
// source's no-metadata branch (title = station name, subtitle = desc).
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { FRadioPlayerMetadata } from '../model/TrackMetadata';

const DOMAIN: number = 0x0001;
const TAG: string = 'TrackMetadata';
const ICY_TIMEOUT_MS: number = 15000;
const ICY_MAX_BYTES: number = 512 * 1024;
const ICY_MAX_BLOCKS: number = 4;
const ICY_HEADERS: Record<string, string> = { 'Icy-MetaData': '1' };
export const ICY_POLL_INTERVAL_MS: number = 30000;

interface ITunesTrackResult {
  artworkUrl100?: string;
}

interface ITunesResponse {
  results?: ITunesTrackResult[];
}

// iTunesAPI(artworkSize:) - GET https://itunes.apple.com/search?term=<rawValue>&entity=song,
// results[0].artworkUrl100 with "100x100" -> "<size>x<size>".
export class ITunesAPI {
  readonly artworkSize: number;

  constructor(artworkSize: number) {
    this.artworkSize = artworkSize;
  }

  async getArtwork(metadata: FRadioPlayerMetadata): Promise<string | undefined> {
    const raw: string | undefined = metadata.rawValue;
    if (metadata.isEmpty || raw === undefined) {
      return undefined;
    }
    const url: string = `https://itunes.apple.com/search?term=${encodeURIComponent(raw)}&entity=song`;
    const req: http.HttpRequest = http.createHttp();
    try {
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: ICY_TIMEOUT_MS,
        readTimeout: ICY_TIMEOUT_MS
      };
      const resp: http.HttpResponse = await req.request(url, options);
      if (resp.responseCode < 200 || resp.responseCode > 299) {
        return undefined;
      }
      const body: ITunesResponse = JSON.parse(resp.result as string) as ITunesResponse;
      const results: ITunesTrackResult[] | undefined = body.results;
      if (results === undefined || results.length === 0) {
        return undefined;
      }
      const art: string | undefined = results[0].artworkUrl100;
      if (art === undefined || art.length === 0) {
        return undefined;
      }
      const size: number = this.artworkSize;
      return (size !== 100 && size > 0) ? art.replace('100x100', `${size}x${size}`) : art;
    } catch (e) {
      return undefined;
    } finally {
      req.destroy();
    }
  }
}

function concat(a: Uint8Array, b: Uint8Array): Uint8Array {
  const out: Uint8Array = new Uint8Array(a.length + b.length);
  out.set(a, 0);
  out.set(b, a.length);
  return out;
}

function headerValue(headers: Object, name: string): string | undefined {
  const rec: Record<string, Object> = headers as Record<string, Object>;
  const keys: string[] = Object.keys(rec);
  for (const k of keys) {
    if (k.toLowerCase() === name) {
      return String(rec[k]);
    }
  }
  return undefined;
}

// StreamTitle='...'; inside an ICY metadata block (NUL-padded to a multiple of 16 bytes).
export function parseStreamTitle(block: string): string | undefined {
  const m: RegExpMatchArray | null = block.match(new RegExp("StreamTitle='(.*?)';"));
  if (m === null) {
    return undefined;
  }
  const title: string = m[1].trim();
  return title.length > 0 ? title : undefined;
}

export class TrackMetadataService {
  private timer: number = -1;
  private generation: number = 0;

  // One ICY probe. Resolves the stream's current StreamTitle as metadata, or undefined.
  async fetchIcyMetadata(streamURL: string): Promise<FRadioPlayerMetadata | undefined> {
    const req: http.HttpRequest = http.createHttp();
    try {
      const raw: string | undefined = await this.readIcyTitle(req, streamURL);
      return FRadioPlayerMetadata.fromRaw(raw);
    } catch (e) {
      return undefined;
    } finally {
      req.off('headersReceive');
      req.off('dataReceive');
      req.off('dataEnd');
      req.destroy(); // aborts the side stream after the first metadata block
    }
  }

  // Streams the response until the first ICY metadata block (or timeout / end).
  // The caller owns `req` and destroys it in its finally block.
  private readIcyTitle(req: http.HttpRequest, streamURL: string): Promise<string | undefined> {
    return new Promise<string | undefined>(
      (resolve: (v: string | undefined) => void) => {
        let done: boolean = false;
        let metaInt: number = 0;
        let buf: Uint8Array = new Uint8Array(0);
        let guard: number = -1;
        const finish = (v: string | undefined): void => {
          if (!done) {
            done = true;
            clearTimeout(guard);
            resolve(v);
          }
        };
        guard = setTimeout(() => finish(undefined), ICY_TIMEOUT_MS);

        req.on('headersReceive', (headers: Object) => {
          const v: string | undefined = headerValue(headers, 'icy-metaint');
          metaInt = v !== undefined ? parseInt(v) : 0;
          if (isNaN(metaInt) || metaInt <= 0) {
            finish(undefined); // stream sends no ICY metadata
          }
        });
        req.on('dataReceive', (chunk: ArrayBuffer) => {
          if (done || metaInt <= 0) {
            return;
          }
          buf = concat(buf, new Uint8Array(chunk));
          // Walk metadata blocks: [metaInt audio bytes][len byte][len*16 metadata bytes]...
          let pos: number = metaInt;
          let blocks: number = 0;
          while (pos < buf.length && blocks < ICY_MAX_BLOCKS) {
            const len: number = buf[pos] * 16;
            if (pos + 1 + len > buf.length) {
              break; // wait for the rest of this block
            }
            if (len > 0) {
              const text: string = util.TextDecoder.create('utf-8')
                .decodeToString(buf.subarray(pos + 1, pos + 1 + len));
              finish(parseStreamTitle(text));
              return;
            }
            blocks++;
            pos = pos + 1 + metaInt;
          }
          if (blocks >= ICY_MAX_BLOCKS || buf.length > ICY_MAX_BYTES) {
            finish(undefined);
          }
        });
        req.on('dataEnd', () => finish(undefined));

        const options: http.HttpRequestOptions = {
          method: http.RequestMethod.GET,
          header: ICY_HEADERS,
          connectTimeout: ICY_TIMEOUT_MS,
          readTimeout: ICY_TIMEOUT_MS
        };
        req.requestInStream(streamURL, options).catch(() => finish(undefined));
      });
  }

  // Probe now and every ICY_POLL_INTERVAL_MS until stop(); onMetadata gets each result.
  start(streamURL: string, onMetadata: (m: FRadioPlayerMetadata | undefined) => void): void {
    this.stop();
    const gen: number = this.generation;
    const poll = async (): Promise<void> => {
      const m: FRadioPlayerMetadata | undefined = await this.fetchIcyMetadata(streamURL);
      if (gen === this.generation) {
        hilog.info(DOMAIN, TAG, 'TrackMetadata: %{public}s', m?.rawValue ?? '<none>');
        onMetadata(m);
      }
    };
    poll();
    this.timer = setInterval(() => {
      poll();
    }, ICY_POLL_INTERVAL_MS);
  }

  stop(): void {
    this.generation++;
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }
}
