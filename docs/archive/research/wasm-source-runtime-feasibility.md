# WASM Source Runtime Feasibility

Date: 2026-05-21

This document is a research/design slice for a possible future Koma source runtime. It does not define v1 scope and must not be treated as approval to add executable plugin loading to production app code. Koma v1 remains AppGallery-safe: local comics, reading progress, and user-owned private libraries such as Komga, OPDS, and WebDAV.

Koma may study Aidoku-style source extensibility as public architecture inspiration, but must not copy Aidoku/Homo code, assets, source packages, manifests, or compatibility claims. Koma should not ship built-in public manga sources, source marketplaces, remote source indexes, APK plugins, or "free/all-web manga" positioning.

## Executive Recommendation

Do not ship a WASM source runtime in v1.

The safest staged path is:

1. Keep v1 focused on local imports and private-library adapters.
2. Extend Komga, OPDS, and WebDAV before any generic source runtime.
3. If custom adaptation is still needed, try a constrained declarative JSON/YAML rule engine before executable WASM.
4. Treat WASM as a local, artifact-only technical spike until AppGallery, HarmonyOS API, sandbox, and licensing questions are explicitly cleared.

The smallest acceptable WASM spike is a bundled hello-world module loaded only by a test or isolated native sample, with no remote download, no user source UI, no network access, no marketplace, and no production reader integration.

## Evidence and Verification Status

Verified from the local HarmonyOS reference snapshot:

- `@ohos.net.http` supports host-owned HTTP requests and requires `ohos.permission.INTERNET`. Its normal request path is documented as suitable for responses up to 5 MB unless `maxLimit` is changed, and larger content should use `requestInStream`.
- `HttpRequestOptions` exposes `readTimeout`, `connectTimeout`, `maxLimit`, `caPath`, `caData`, certificate pinning, and API 23 `customMethod`, including an explicit WebDAV use case.
- HarmonyOS Node-API exists for native modules: the documentation shows `#include <napi/native_api.h>` and `libace_napi.z.so`, and describes HarmonyOS as reimplementing Node-API over ArkJS and related engines.
- JSVM native headers include WebAssembly-related APIs such as `OH_JSVM_CompileWasmModule`, `OH_JSVM_CompileWasmFunction`, `OH_JSVM_IsWasmModuleObject`, and `OH_JSVM_CreateWasmCache`. The same docs warn that WASM execution/optimization may depend on JIT permission and can return `JSVM_JIT_MODE_EXPECTED`.
- WebView exposes JavaScript interaction through `WebviewController.runJavaScript`, `javaScriptAccess(true)`, and `registerJavaScriptProxy`. The WebView docs warn that JavaScript proxy injection into untrusted pages can expose the app to attack.

Needs official verification before implementation:

- Whether ArkTS application code can directly use the standard JavaScript `WebAssembly` global in the target API/profile, outside WebView and outside native JSVM.
- Whether AppGallery review policy allows an app-distributed native WASM interpreter or JSVM WASM use when the bytecode is local-only, bundled, and not user-downloadable.
- Whether dynamically loading user-provided `.wasm` files is considered executable code delivery under the current HarmonyOS/AppGallery rules.
- Whether JSVM WASM APIs are available to third-party applications on all target devices without special JIT permissions, and what fallback path is required when `JSVM_JIT_MODE_EXPECTED` appears.

## HarmonyOS Execution Options

| Option | Feasibility | Product/review risk | Current status |
| --- | --- | --- | --- |
| ArkTS `WebAssembly` global | Potentially simplest if supported, but not proven from the local docs. | Medium. Direct bytecode execution in app logic still needs policy review. | Needs official verification. |
| WebView sandbox | Technically plausible because WebView can run JavaScript and bridge to ArkTS, but it is an awkward runtime container for source adapters. | Medium to high. `runJavaScript` and JS proxy injection increase attack surface; a hidden WebView runtime can look like script execution plumbing. | Avoid as primary route. Consider only for rendering trusted private pages, not source modules. |
| Native JSVM WASM | Local docs show native JSVM WebAssembly compile/cache APIs. This may be closer to platform primitives than embedding a third-party runtime. | Medium. JIT permission and executable bytecode review risk need clarification. | Good research candidate, but not production-ready. |
| Native WAMR/wasm3 via Node-API | Plausible through NDK/Node-API. WAMR offers more lifecycle/sandbox controls; wasm3 is lighter for a spike. | Medium. Embedding an interpreter is easier to explain than remote script execution, but user-downloadable modules are still risky. | Best isolated spike route if WASM research continues. |
| Deferred/no runtime | Fully feasible. | Lowest. | Recommended for v1. |

Recommendation: if a WASM spike is approved, start with native WAMR or wasm3 in a non-production sample/test harness. Keep JSVM WASM as a parallel research note because it may avoid third-party runtime dependency, but do not assume JIT/runtime availability until verified on target devices.

## Security and AppGallery Risk

Highest-risk features:

- Remote source downloading or source index URLs.
- User-imported executable `.wasm`, JavaScript, or native payloads.
- Source marketplace, rankings, recommended source lists, or one-click public source import.
- Built-in rules for public manga sites.
- Obfuscated source payloads, encrypted modules, self-updating adapters, or runtime code generation.
- Host APIs that expose arbitrary network, filesystem, credentials, cookies, clipboard, device identifiers, or logs.

Safest staged positioning:

- v1 wording: "local comics", "private library", "your own Komga/OPDS/WebDAV server", "local import".
- Future research wording: "advanced custom adapter for services you control or have permission to access".
- Default state: disabled and absent from first-run flows.
- Distribution: no bundled public sources, no marketplace, no remote index, no source sharing features in AppGallery builds.
- Import policy if ever enabled: user-selected local file only, explicit manifest review, domain allowlist, and a visible warning that Koma does not provide content sources.

## Minimal ABI Shape

A future source module should be a pure adapter. The host owns all dangerous capabilities.

Required module calls:

- `init(manifest)`: validate schema and feature flags.
- `search(query, page)`: return normalized search results.
- `detail(comicId)`: return metadata and chapter list.
- `pages(chapterId)`: return ordered page descriptors.
- `cancel(callId)` or host-side cancellation token: stop long-running work.
- `free(ptr, len)` only if the chosen ABI uses linear-memory ownership.

Required host APIs:

- `http_fetch(request)`: the only network boundary. Enforce manifest domain allowlist, HTTPS by default, redirect checks, response size caps, method allowlist, timeout, and cancellation.
- `parse_html` / `select_html` and `parse_json` / `json_path`: prefer host-provided parsing to avoid every module bundling parsers and to centralize memory limits.
- `cache_get` / `cache_put`: namespaced per source and capped by size/TTL.
- `log(level, message)`: redacts URLs, credentials, cookies, tokens, and headers by default.
- `now_ms`: host-provided time only if needed for cache or signatures.
- `yield_or_check_cancel`: lets the host interrupt long loops when the runtime supports it.

Forbidden module capabilities:

- No raw filesystem access.
- No raw sockets.
- No process/thread spawning.
- No native dynamic library loading.
- No direct credential, cookie, or token storage.
- No arbitrary cross-domain network.
- No writes outside a host-managed source cache namespace.

Data rules:

- Module storage cannot contain secrets. Credentials live in Koma account settings and are referenced by opaque `credentialsRef` values.
- Returned images/pages are descriptors, not downloaded bytes. Koma fetches images through its own network/cache pipeline.
- All errors cross the ABI as redacted structured envelopes, not raw exception traces.

## Alternatives

| Alternative | Why it should precede WASM |
| --- | --- |
| Local-only imports | Already aligned with Koma v1 and has the lowest policy risk. |
| Komga/OPDS/WebDAV extensions | User-owned private-library protocols are easier to explain, test, and review than arbitrary source code. |
| Declarative JSON/YAML rules | No user code execution; host can keep schema intentionally small with domain allowlists, selectors, pagination, and response caps. |
| WASM runtime | More powerful but introduces executable content, sandbox, licensing, toolchain, and review risk. |

Declarative rules should come before WASM if Koma needs custom adaptation beyond private-library protocols. The first rules schema should be intentionally limited: fixed request templates, CSS selector/JSONPath extraction, pagination, domain allowlist, and no scripting language.

## MVP Spike Plan

Goal: prove whether HarmonyOS can execute a tiny bundled WASM module under controlled conditions without creating a product feature.

Scope:

- Local bundled hello-world WASM only.
- No remote download.
- No source import UI.
- No marketplace, source list, or public catalog wording.
- No network host import.
- No filesystem host import except reading the bundled fixture/module if the test harness requires it.
- Artifact-only logs under `.hermes-artifacts/`.

Steps:

1. Create an isolated spike branch or sample module outside production reader/source flows.
2. Compile a trivial WASM function such as `add(2, 3) -> 5` or `version() -> "hello"`.
3. Test one candidate runtime at a time: JSVM WASM, WAMR interpreter, or wasm3 interpreter.
4. Measure build integration, package size delta, startup cost, call latency, memory ceiling behavior, crash behavior, and timeout/cancellation options.
5. Record device evidence, runtime errors, and policy questions. Do not expose any UI in the app.

Pass criteria:

- The module is bundled locally and deterministic.
- The host can instantiate, call, and tear down the runtime repeatedly.
- Failure modes are caught without crashing the app process in the normal path.
- The spike documents whether JIT permission or device-specific support is required.

Fail/stop criteria:

- Runtime requires broad JIT or private permissions.
- Runtime cannot enforce memory/time limits.
- Integration requires production app source loading surfaces.
- Review/policy feedback treats the runtime as prohibited dynamic executable content.

## Licensing Notes

- Aidoku can inform high-level architecture topics: manifest-first packages, host APIs, normalized DTOs, and source isolation.
- Koma must not copy GPL code, source implementations, build scripts, schemas that are copyrightable as expression, icons, bundled sources, or documentation text.
- Koma should not claim Aidoku source compatibility unless a future legal and technical review explicitly approves it.
- If WAMR, wasm3, parsers, or other third-party components are used in a spike, capture license, notice, source URL, version, and redistribution obligations before committing vendored code.

## Decision

For Lane 3B, the design answer is: defer production WASM, prioritize private-library adapters and then constrained declarative rules, and keep any WASM work as a local bundled technical spike with no remote source mechanics. This keeps Koma aligned with the current AppGallery-safe positioning while preserving a measured path to evaluate runtime viability.

