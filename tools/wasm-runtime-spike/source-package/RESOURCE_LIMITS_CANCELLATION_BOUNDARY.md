# Resource Limits, Cancellation, and Timeout Boundary

This is a design/tooling-only boundary for the future Koma WASM source runtime.
It documents policy that package tooling can validate before any product runtime
integration exists. It does not enable network, add host imports, change WAMR
behavior, execute source packages in product code, or define a source market.

Current runtime evidence remains closed:

- `permissions.network` is `false`.
- The only host imports are `koma_host.log` and `koma_host.check_cancel`.
- HTTP/auth/resource policies are static metadata and fixtures only.
- Any unsupported capability, import, executable flag, or leak fails closed.

## Result Budgets

Hosts should treat source operation output as bounded data, not a stream.
Future-compatible package metadata may declare per-operation budgets under
`resourceLimits.results`, with host defaults at or below these design ceilings:

- `maxResultJsonBytes`: maximum UTF-8 JSON payload returned by one source call.
- `maxResultBufferBytes`: maximum KOMA result buffer including header/padding.
- `maxSearchItems`, `maxChapterItems`, `maxPageItems`: maximum returned list
  items for search, chapter list, and page list calls.
- `maxPageCountPerChapter`: maximum declared page count for one chapter.
- `truncation`: `error`, unless a future host explicitly supports deterministic
  partial results with a `truncated=true` envelope.

Current tooling expects fail-closed behavior. If a result exceeds a budget, the
host maps it to a structured error instead of returning partial unmarked data:

```json
{
  "ok": false,
  "error": {
    "code": "RESOURCE_LIMIT_EXCEEDED",
    "message": "resource limit exceeded",
    "retryable": false
  }
}
```

Logs must include only the operation, opaque request id when available, limit
name, and observed/redacted byte or count metadata. Logs must not include result
JSON bodies, page URLs, local paths, headers, cookies, tokens, or credentials.

## WASM and Module Budgets

Package metadata may declare static limits under `resourceLimits.wasm`:

- `maxWasmBytes`: maximum module bytes accepted by package validation.
- `maxMemoryPages`: maximum WebAssembly linear memory pages.
- `maxHeapBytes` and `maxStackBytes`: future host allocation hints.
- `maxCallDepth`: SDK/host guardrail for recursive source code.
- `operationBudget`: deterministic unit budget when a future interpreter or SDK
  can enforce one. Until then, wall-clock timeout and cancellation are the
  enforceable boundary.

The current validator accepts only small fixture budgets and rejects drift toward
large modules, unbounded memory, or executable/product-runtime flags. Runtime
load, instantiate, and call failure must map to an error envelope and should not
fall back to a less restricted execution path.

## Timeout Policy

Each source operation should have a host-owned wall-clock budget declared under
`resourceLimits.timeouts.perOperationMs`. Design fixtures use one budget per
operation:

- `search`
- `get_manga`
- `get_chapters`
- `get_pages`

Timeouts must be positive integers and remain below the host maximum. The host,
not source code, owns timeout measurement. On timeout, the host cancels the call,
tears down or quarantines the module instance as needed, frees host-owned
buffers, and returns:

```json
{
  "ok": false,
  "error": {
    "code": "TIMEOUT",
    "message": "operation timed out",
    "retryable": true
  }
}
```

Timeout logs must be redacted and should identify only the source package id,
operation, request id, timeout budget, and elapsed metadata.

## Cancellation Policy

The current fixture SDK imports `koma_host.check_cancel`, and future source SDKs
must keep that import while cancellation is required. Source code is expected to
poll before and during loops that parse, allocate, enumerate search results,
build chapter lists, or build page lists. A source should stop promptly when the
host reports cancellation and return a cancellation envelope when it can do so:

```json
{
  "ok": false,
  "error": {
    "code": "CANCELLED",
    "message": "operation cancelled",
    "retryable": true
  }
}
```

If source code does not return after cancellation, the host remains authoritative
and maps the call to `CANCELLED` or `TIMEOUT` depending on the observed boundary.
Cancellation does not authorize extra imports, threads, network access, or
process-wide termination behavior.

## Manifest Resource Policy

`resource-limits.example.json` is the design-only schema example for this lane.
It intentionally repeats the current closed runtime facts alongside future
limits so validators can catch drift:

- `designOnly=true`
- `runtimeEnabled=false`
- `currentRuntime.network=false`
- `currentRuntime.hostImports=["koma_host.log","koma_host.check_cancel"]`
- `resourceLimits.cancellation.required=true`
- no remote URLs, local paths, credential literals, unsafe log bodies, source
  markets, product-runtime flags, or executable hooks

The current package manifest still uses `runtime.limits` for the local fixture.
The future `resourceLimits` object is documentation/tooling evidence only until
a product runtime explicitly implements it.

## Static Validator

Run:

```sh
python3 tools/wasm-runtime-spike/source-package/validate-resource-limit-fixtures.py \
  --fixture-dir tools/wasm-runtime-spike/source-package/resource-limit-fixtures \
  --artifact-dir /path/to/artifacts/resource-limit-fixtures
```

The validator is Python stdlib only. It reads local JSON fixtures, executes no
WASM, launches no subprocesses, performs no network I/O, writes a JSON report,
accepts valid policy examples, and rejects negative fixtures for oversized
budgets, invalid timeouts, disabled/omitted cancellation, forbidden host imports,
`network=true`, remote/path/credential leaks, unsafe logs, and executable or
product-runtime flags.
