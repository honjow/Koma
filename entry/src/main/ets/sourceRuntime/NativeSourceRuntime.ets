import nativeRuntime from 'libkoma_source_runtime.so';
import { sourceRuntimeExecutionSourceId } from './SourceRuntimeExecutionIdentity';

export interface SourceBrowserHttpResult { eligible: boolean; cancelled: boolean; code: number; status: number; body: string; headers: string[] }

interface NativeSourceRuntimeModule {
  sourceBrowserHttp(id: string, url: string, headers: string[], timeout: number, profile: string): Promise<SourceBrowserHttpResult>;
  cancelSourceBrowserHttp(id: string): void;
  javaRegex(pattern: string, texts: string[]): Promise<NativeJavaRegexResult>;
  hello(): string;
  add(a: number, b: number): number;
  runJsonCall(requestJson: string): string;
  runJsonCallFromBytes(requestJson: string, wasmBytes: Uint8Array, httpContextJson?: string, sourceId?: string): string;
  configureHttpTransport(transport: SourceRuntimeHttpTransport): boolean;
  sourcePackageFilesMatch(paths: string[], expectedByteCounts: number[]): boolean;
}

export interface NativeJavaRegexResultData { valid: boolean; texts: string[] }
export interface NativeJavaRegexResult { ok: boolean; data: NativeJavaRegexResultData }

const nativeSourceRuntime = nativeRuntime as NativeSourceRuntimeModule;

export type SourceRuntimeHttpTransport = (requestJson: string, httpContextJson?: string) => Promise<string>;

export type SourceRuntimeCallRequest = Record<string, Object | string | number | boolean | null>;

export interface SourceRuntimeFixtureData {
  requestEcho?: string;
  items?: Array<Record<string, Object | string | number | boolean | null>>;
}

export interface SourceRuntimeCallResponse {
  ok: boolean;
  runtime?: string;
  type?: string;
  version?: number;
  operation?: string;
  requestEcho?: string;
  data?: SourceRuntimeFixtureData;
  error?: Record<string, Object | string | number | boolean | null>;
  reasonCode?: string;
  hostHints?: Record<string, Object | string | number | boolean | null>;
}

export class NativeSourceRuntime {
  static sourceBrowserHttp(id: string, url: string, headers: string[], timeout: number, profile: string): Promise<SourceBrowserHttpResult> {
    return nativeSourceRuntime.sourceBrowserHttp(id, url, headers, timeout, profile)
  }
  static cancelSourceBrowserHttp(id: string): void { nativeSourceRuntime.cancelSourceBrowserHttp(id) }
  static javaRegex(pattern: string, texts: string[]): Promise<NativeJavaRegexResult> {
    return nativeSourceRuntime.javaRegex(pattern, texts)
  }
  static hello(): string {
    return nativeSourceRuntime.hello();
  }

  static add(a: number, b: number): number {
    return nativeSourceRuntime.add(a, b);
  }

  static runJsonCall(request: SourceRuntimeCallRequest | string): SourceRuntimeCallResponse {
    const requestJson = typeof request === 'string' ? request : JSON.stringify(request);
    const responseJson = nativeSourceRuntime.runJsonCall(requestJson);
    return JSON.parse(responseJson) as SourceRuntimeCallResponse;
  }

  static runJsonCallFromBytes(request: SourceRuntimeCallRequest | string, wasmBytes: Uint8Array, httpContextJson: string = ''): SourceRuntimeCallResponse {
    const requestJson = typeof request === 'string' ? request : JSON.stringify(request);
    const responseJson = nativeSourceRuntime.runJsonCallFromBytes(requestJson, wasmBytes, httpContextJson,
      sourceRuntimeExecutionSourceId(httpContextJson));
    return JSON.parse(responseJson) as SourceRuntimeCallResponse;
  }

  static sourcePackageFilesMatch(paths: string[], expectedByteCounts: number[]): boolean {
    return nativeSourceRuntime.sourcePackageFilesMatch(paths, expectedByteCounts);
  }

  static configureHttpTransport(transport: SourceRuntimeHttpTransport): boolean {
    return nativeSourceRuntime.configureHttpTransport(transport);
  }
}
