# Koma WASM Runtime Spike

This is a repo-local, non-shipping runtime spike for the future source ABI. It
does not add product UI, source import, source lists, network integrations, or
HarmonyOS app behavior.

The spike validates this path on Linux:

```text
C fixture source -> clang wasm32 -> WAMR interpreter host -> KOMA JSON envelope
```

## Run

```sh
bash tools/wasm-runtime-spike/run.sh
```

By default the script writes build products, WAMR cache, and logs under:

```text
.hermes-artifacts/wasm-runtime-spike/
```

For controller runs, point it at the assigned artifact directory:

```sh
KOMA_WASM_SPIKE_ARTIFACT_DIR=/home/gamer/git/Koma/.hermes-artifacts/20260521-115841/lane3c-wasm-runtime-spike \
  bash tools/wasm-runtime-spike/run.sh
```

The script pins WAMR to `WAMR-2.3.0` commit
`c7b2db18329f849b81568b94e72ddd0b20f431a5`. If no `WAMR_ROOT_DIR` is provided,
it clones that tag into the ignored artifact cache. WAMR source is not vendored
or committed to this repository.

Expected evidence in the log:

```text
ADD_OK add(2,3)=5
INIT_OK manifest accepted
SEARCH_OK magic=KOMA flags=1 len=...
SEARCH_JSON={"ok":true,...}
WAMR_SPIKE_PASS
```

The host runner validates:

- WAMR initializes, loads, instantiates, calls, and disposes the module.
- `add(2,3)` returns `5`.
- A JSON request buffer is copied into wasm memory.
- `koma_source_search(ptr,len)` returns a result buffer with `KOMA` magic,
  flags, payload length, and UTF-8 JSON envelope.
- `koma_source_free(ptr)` is called after the host reads the payload.

## HarmonyOS NAPI Next Step

Keep this isolated from production app behavior. The next narrow integration
step is a native sample module exposing only `hello`, `add`, and
`runJsonCall(wasmBytes, manifestJson, functionName, requestJson)` through
Node-API. That native module should reuse the same ABI flow demonstrated here:
per-call WAMR init/load/instantiate, host-owned request buffers, KOMA envelope
validation, response free, and teardown. Do not add source marketplace UI,
remote source indexes, or real network host imports in that slice.
