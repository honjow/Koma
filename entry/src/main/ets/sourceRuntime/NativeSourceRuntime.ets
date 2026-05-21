import nativeRuntime from 'libkoma_source_runtime.so';

interface NativeSourceRuntimeModule {
  hello(): string;
  add(a: number, b: number): number;
  runJsonCall(requestJson: string): string;
  runJsonCallFromBytes(requestJson: string, wasmBytes: Uint8Array): string;
}

const nativeSourceRuntime = nativeRuntime as NativeSourceRuntimeModule;

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
  hostHints?: Record<string, Object | string | number | boolean | null>;
}

export class NativeSourceRuntime {
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

  static runJsonCallFromBytes(request: SourceRuntimeCallRequest | string, wasmBytes: Uint8Array): SourceRuntimeCallResponse {
    const requestJson = typeof request === 'string' ? request : JSON.stringify(request);
    const responseJson = nativeSourceRuntime.runJsonCallFromBytes(requestJson, wasmBytes);
    return JSON.parse(responseJson) as SourceRuntimeCallResponse;
  }
}
