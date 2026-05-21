import nativeRuntime from 'libkoma_source_runtime.so';

interface NativeSourceRuntimeModule {
  hello(): string;
  add(a: number, b: number): number;
  runJsonCall(requestJson: string): string;
}

const nativeSourceRuntime = nativeRuntime as NativeSourceRuntimeModule;

export type SourceRuntimeCallRequest = Record<string, Object | string | number | boolean | null>;

export interface SourceRuntimeFixtureData {
  requestEcho?: string;
}

export interface SourceRuntimeCallResponse {
  ok: boolean;
  runtime?: string;
  requestEcho?: string;
  data?: SourceRuntimeFixtureData;
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
}
