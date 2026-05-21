# Koma Rust Source SDK Spike

This crate is a non-shipping, test-only boundary sketch for Rust WASM source
authors. It keeps raw ABI details in a Koma-owned `no_std` layer while the
fixture source stays focused on source behavior.

The SDK intentionally covers only the current spike:

- `koma_host.log` and `koma_host.check_cancel` host imports.
- `hostHints.network=false` response convention.
- Minimal request matching for the fixture search request.
- KOMA result buffer header writing for the existing WAMR host runner.

It does not enable HTTP, network access, source markets, remote install, or any
HarmonyOS product runtime path.
