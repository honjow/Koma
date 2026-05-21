# Koma Rust Source SDK Spike

This crate is a non-shipping, test-only boundary sketch for Rust WASM source
authors. It keeps raw ABI details in a Koma-owned `no_std` layer while the
fixture source stays focused on source behavior.

The SDK intentionally covers only the current spike:

- `koma_host.log` and `koma_host.check_cancel` host imports.
- `hostHints.network=false` response convention.
- A provisional `Source` trait with `SourceInfo`, `SearchRequest`,
  `MangaId`, `ChapterListRequest`, and `ChapterId` wrappers.
- SDK-owned operation runners for `search`, `get_manga`, `get_chapters`, and
  `get_pages` that handle ABI request reads, operation checks, cancellation,
  JSON response envelope writing, and KOMA result buffer headers.
- KOMA result buffer header writing for the existing WAMR host runner.

It does not enable HTTP, network access, source markets, remote install, or any
HarmonyOS product runtime path.

The fixture under `../rust-fixture` demonstrates the intended author-facing
shape for this spike:

1. Define a zero-sized source type.
2. Implement `Source` with static JSON data fragments for each operation.
3. Keep exported ABI symbols as thin calls into `koma_source_sdk::source::*`.

This is deliberately not a final public API. The request wrappers currently do
minimal byte matching so the direct `rustc`/`no_std` wasm build stays small and
does not require allocation or JSON dependencies.

Rerun the local runtime smoke with:

```sh
HOME=/home/gamer ./tools/wasm-runtime-spike/run-rust-fixture.sh \
  --artifact-dir /tmp/koma-rust-fixture-runtime-smoke
```

The script pins the wasm build to `target-cpu=mvp` and disables
`reference-types` because the current WAMR smoke host is built with reference
types off.
