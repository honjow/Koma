# Task: Extract shared utility functions from sources into koma_source_sdk

## Context
Two WASM source implementations (baozimh and mangadex) in `tools/sources/` both contain duplicated utility functions for JSON building and parsing. These should be moved into the shared SDK crate at `tools/wasm-runtime-spike/rust-sdk/src/lib.rs`.

## Duplicated Functions to Extract
Both sources duplicate these patterns (check both `tools/sources/first-real-source/src/lib.rs` and `tools/sources/mangadex/src/lib.rs`):

1. `write_bytes(dst, cursor, src)` — write raw bytes to buffer
2. `write_usize(dst, cursor, val)` — write integer as decimal string
3. `append_json_escaped(dst, cursor, src)` — write bytes with JSON string escaping
4. `find_subslice(haystack, needle)` — find byte pattern in slice
5. `write_url_encoded(dst, cursor, src)` — percent-encode bytes
6. `extract_json_string(data, key)` — find `"key":"value"` and return value slice
7. `extract_json_number(data, key)` — find `"key":123` and return number slice
8. `contains_bytes(haystack, needle)` — check if pattern exists
9. `append_json_unescaped_then_escaped(dst, cursor, src)` — unescape JSON then re-escape for output (mangadex only, but useful as SDK utility)
10. `append_json_escaped_byte(dst, cursor, b)` — single byte JSON-escape helper
11. `hex_to_u16(hex)` / `encode_utf8(cp, buf)` — unicode helpers for JSON unescape
12. `JsonArrayIter` — iterate objects in a JSON array by key

## Requirements

1. Move the above functions/types into `tools/wasm-runtime-spike/rust-sdk/src/lib.rs` as public items in a new module section (e.g., after existing code, in a clearly marked `// === JSON/Buffer Utilities ===` section)
2. Make them `pub` so sources can use them via `koma_source_sdk::`
3. Update both source `lib.rs` files to remove their local copies and import from SDK
4. The SDK is a `no_std` crate — ensure all additions are `no_std` compatible (no alloc, no std)
5. Both sources must still compile to wasm32-unknown-unknown after the refactor
6. Use this exact build command to verify: `RUSTUP_HOME=/home/gamer/.rustup CARGO_HOME=/home/gamer/.cargo PATH="/home/gamer/.cargo/bin:$PATH" cargo build --release --target wasm32-unknown-unknown`
7. Run the build in BOTH source directories to verify

## Build Verification
After changes, run:
```bash
cd /home/gamer/git/Koma/tools/sources/first-real-source && RUSTUP_HOME=/home/gamer/.rustup CARGO_HOME=/home/gamer/.cargo PATH="/home/gamer/.cargo/bin:$PATH" cargo build --release --target wasm32-unknown-unknown
cd /home/gamer/git/Koma/tools/sources/mangadex && RUSTUP_HOME=/home/gamer/.rustup CARGO_HOME=/home/gamer/.cargo PATH="/home/gamer/.cargo/bin:$PATH" cargo build --release --target wasm32-unknown-unknown
```

## Functional Verification
After build succeeds, run dev runner tests:
```bash
cd /home/gamer/git/Koma
DEV=tools/koma-source-dev/target/release/koma-source-dev
$DEV run --op search --request '{"query":"one piece"}' tools/sources/mangadex/target/wasm32-unknown-unknown/release/koma_mangadex_source.wasm 2>/dev/null | python3 -c "import sys,json;d=json.load(sys.stdin);print(f'mangadex search ok={d[\"ok\"]} items={len(d[\"data\"][\"items\"])}')"
$DEV run --op search --request '{"query":"斗罗"}' tools/sources/first-real-source/target/wasm32-unknown-unknown/release/koma_first_real_source.wasm 2>/dev/null | python3 -c "import sys,json;d=json.load(sys.stdin);print(f'baozimh search ok={d[\"ok\"]} items={len(d[\"data\"][\"items\"])}')"
```

## Commit
When done, commit with message: `refactor(sdk): extract shared JSON/buffer utilities from sources into koma_source_sdk`

## Notes
- The SDK already has some content (1303 lines) — add new utilities below existing code
- Both sources use `use koma_source_sdk::*;` style imports — keep it simple
- Don't change the source logic or output format, only move utility code location
- If a function exists in mangadex but not baozimh (like `append_json_unescaped_then_escaped`), still move it to SDK — baozimh may need it later
