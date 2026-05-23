# Source-Runtime Productization Decision Checkpoint

This document is a tooling/docs-only checkpoint for the Koma WASM source-runtime
track after S18A–S18I. It does not introduce product scope and does not change
the current local/dev boundary. It exists so the next decision about
productization can be made deliberately rather than by drift.

## Status

The local/dev source-author SDK, Source API v0.2 surface, and accompanying docs
are now stable enough for source-author iteration against fixtures and the
evidence suite. The runtime stays sandboxed, `network=false`, and host-import
controlled, and there is no product runtime, UI, or remote install behind any
of this work.

## Stabilized surfaces

- Source API v0.2 operation surface and JSON fixture corpus, with the full
  evidence suite chaining direct Rust/WAMR execution, archive smoke,
  operation-surface parity, and Source API v0.2 JSON fixture validation
  (see [`SOURCE_API_V0.md`](SOURCE_API_V0.md) and the suite wrapper
  `run-source-runtime-evidence-suite.py`).
- Source-author docs index covering the stabilization audit, quickstart,
  compatibility checklist, and SDK parity guide:
  - [`SOURCE_AUTHOR_STABILIZATION_AUDIT.md`](SOURCE_AUTHOR_STABILIZATION_AUDIT.md)
  - [`SOURCE_AUTHOR_QUICKSTART.md`](SOURCE_AUTHOR_QUICKSTART.md)
  - [`SOURCE_AUTHOR_COMPATIBILITY_CHECKLIST.md`](SOURCE_AUTHOR_COMPATIBILITY_CHECKLIST.md)
  - [`SOURCE_AUTHOR_FIXTURE_SDK_PARITY.md`](SOURCE_AUTHOR_FIXTURE_SDK_PARITY.md)
  - [`README.md`](README.md) "Source Author Docs" section as the index entry.
- `SourceCapabilities::FULL_V02_FIXTURE` SDK helper so authors can advertise the
  full v0.2 fixture capability set without hand-rolling flags, documented in the
  SDK parity guide and quickstart.
- `Request::contains_json_number`, `SearchRequest::limit_is`, and
  `MangaListRequest::limit_is` SDK accessors for `no_std`-safe
  envelope/argument inspection, documented alongside existing byte-substring
  helpers in the quickstart and parity guide.
- Fail-closed evidence/negative-contract validators:
  - `validate-evidence-suite-negative-contract.py` proves the suite reports
    `FAIL` and surfaces both `step exit` and `missing expected report`
    findings when a step exits nonzero without writing its expected report.
  - `validate-archive-negative-fixtures.py` proves the archive validator
    rejects traversal, absolute paths, duplicates, symlinks, unexpected
    entries, network/http drift, wasm hash mismatch, and missing entries.

## Non-goals still preserved

The stabilization above is explicitly local/dev source-author scope. None of the
following has been started or is implied by this checkpoint:

- No product UI (bookshelf, reader, source picker, source-management UI).
- No source market or public source index.
- No remote install, remote sync, or remote update channel.
- No built-in/bundled source list or default source catalog.
- No real HTTP or network enablement; fixture HTTP/HTML imports stay
  deterministic local evidence only.
- No trust/signing workflow: no key management, signing, real verification,
  revocation, or trust-store implementation.
- No HarmonyOS product runtime enablement, picker flow, app registry, or
  release-visible source management.

## Decision options

These are the realistic next-step shapes. They are listed so the choice is
explicit; this doc does not pick one.

1. **Continue SDK ergonomics and documentation polish.** Stay inside the
   current local/dev boundary and keep iterating on SDK helpers, docs, and
   evidence wording (e.g. error-code tightening, generated author
   compatibility artifact). No product scope change.
2. **Start dev-only local source-package authoring examples.** Add more
   author-facing example sources that exercise the v0.2 fixture surface
   end-to-end through the existing validators and evidence suite. Still
   local/dev only, still `network=false`, still no product runtime.
3. **Start product UI / runtime integration planning only if explicitly authorized.**
   Open a separately scoped lane that plans how a real product surface (UI,
   ingestion, trust, HarmonyOS runtime) would consume this contract. Must not
   begin under this lane and must keep the non-goals above in force until
   separately approved.

## Verification command pointers

These are the commands already used by the existing docs to keep the contract
honest. They do not need to be re-run for this checkpoint, which is docs-only,
but they remain the source of truth for the surfaces listed above.

```sh
git diff --check
```

```sh
python3 tools/wasm-runtime-spike/source-package/run-source-runtime-evidence-suite.py \
  --artifact-dir /path/to/artifacts/source-runtime-evidence-suite
```

```sh
python3 tools/wasm-runtime-spike/source-package/validate-evidence-suite-negative-contract.py \
  --artifact-dir /path/to/artifacts/evidence-suite-negative-contract
```

```sh
python3 tools/wasm-runtime-spike/source-package/validate-source-api-fixtures.py \
  --fixture-dir tools/wasm-runtime-spike/source-package/source-api-fixtures \
  --artifact-dir /path/to/artifacts/source-api-fixtures
```

For the full README docs index (Source Author Docs, validators, archive,
trust/provenance/canonical-signature/tamper/rotation/lifecycle/settings-auth/
resource-limits/image-page/HarmonyOS-ingestion boundaries), see
[`README.md`](README.md).
