// file: .ts - pure logic. Port of NetworkError (SwiftRadio/Networking/NetworkService.swift:13).
import { BusinessError } from '@kit.BasicServicesKit';

export enum NetworkErrorKind {
  URL_NOT_VALID = 'urlNotValid',
  DATA_NOT_VALID = 'dataNotValid',
  DATA_NOT_FOUND = 'dataNotFound',
  FILE_NOT_FOUND = 'fileNotFound',
  HTTP_RESPONSE_NOT_VALID = 'httpResponseNotValid'
}

// Source enum cases are ordinal: Swift's localizedDescription reads
// "The operation couldn't be completed. (SwiftRadio.NetworkError error <n>.)".
const ORDINALS: NetworkErrorKind[] = [
  NetworkErrorKind.URL_NOT_VALID,
  NetworkErrorKind.DATA_NOT_VALID,
  NetworkErrorKind.DATA_NOT_FOUND,
  NetworkErrorKind.FILE_NOT_FOUND,
  NetworkErrorKind.HTTP_RESPONSE_NOT_VALID
];

// Implements BusinessError so describeError(err) renders it like any Kit failure.
export class NetworkError extends Error implements BusinessError {
  kind: NetworkErrorKind;
  code: number = 0;
  // HTTP status of the failing response (0 when not an HTTP failure), e.g. 403 = GitHub rate limit.
  statusCode: number;

  constructor(kind: NetworkErrorKind, statusCode: number = 0) {
    super(`The operation couldn't be completed. (SwiftRadio.NetworkError error ${ORDINALS.indexOf(kind)}.)` +
      (statusCode > 0 ? ` HTTP ${statusCode}` : ''));
    this.name = 'NetworkError';
    this.kind = kind;
    this.statusCode = statusCode;
  }
}
