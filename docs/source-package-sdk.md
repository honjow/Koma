# Koma Source Package SDK

This document is the compact authoring contract for Koma source packages. Koma supports user-configured source index URLs and local package import, but ships no built-in source market, no default public index URL, and no bundled public sources.

## No built-in source market

Koma source discovery starts from a URL the user configures or from a local package the user picks. Documentation and package metadata must not imply an official bundled market, a default public catalog, or built-in public sources.

## Manifest shape

Source-repo packages use `manifest.json` plus `source.wasm`. The app normalizes that manifest before install:

```json
{
  "id": "local.example.private",
  "name": "Private Example",
  "version": "0.1.0",
  "lang": "en",
  "nsfw": false,
  "author": "Example author",
  "description": "What this source provides.",
  "contentRating": "safe",
  "minAppVersion": "0.1.0",
  "runtime": "wasm-source",
  "entry": "source.wasm",
  "wasmSha256": "<optional sha256 hex>",
  "maxWasmBytes": 131072,
  "capabilities": {
    "network": false,
    "operations": [
      "search",
      "get_manga",
      "get_chapters",
      "get_pages",
      "get_listings",
      "get_manga_list",
      "get_home",
      "get_filters",
      "get_settings",
      "get_image_request"
    ]
  },
  "contentPolicy": {
    "publicIndex": false,
    "marketplace": false,
    "builtInSource": false,
    "remoteInstall": false
  }
}
```

`id`, `name`, and `version` are required. `author`, `description`, `contentRating`, and `minAppVersion` are optional package-owned source metadata; when present they are preserved through local import, update, restart, and backup restore, then shown only in Source Package Manager details. A non-empty `minAppVersion` must be canonical `MAJOR.MINOR.PATCH` text such as `0.1.0`; a missing or empty value means no host-version floor. `id` must be non-empty and at most 96 characters. `capabilities.operations` is optional and may declare supported runtime operations using operation names such as `get_home`, `get_filters`, or `get_settings`; Koma normalizes these into a bounded display summary and ignores unknown operation names. Koma currently rejects packages that request network access, marketplace behavior, built-in-source behavior, remote install behavior, unsafe archive entries, missing WASM, checksum mismatches, malformed minimum-version metadata, or a `minAppVersion` newer than the running Koma app.

## Runtime request envelope

Koma calls source runtimes with a JSON request envelope:

```json
{
  "type": "request",
  "version": 1,
  "requestId": "source-request-id",
  "operation": "search",
  "sourceId": "local.example.private",
  "args": {},
  "settings": {},
  "hostHints": {
    "network": false
  }
}
```

Runtime responses must be JSON envelopes with `ok: true` and `data`, or `ok: false` and a safe `reasonCode`. Supported operations include search/detail/chapter/page flows plus descriptor discovery such as `get_settings`. Do not return raw filesystem paths, picker URIs, cookies, authorization headers, tokens, or secret values in responses, logs, cache keys, or diagnostics.

## Filter descriptor rules

`get_filters` may return descriptors under `data.filters` or `data.items`. Koma supports `text`, `boolean`/`check`, `select`, `sort`, `multiselect`/`multi-select`, `range`, and `group` descriptors. `select`, `sort`, and `multiselect` filters may provide `options` as strings or objects with `id` plus `label`/`name`; Koma displays labels but sends normalized ids in `args.filters`. Multi-select values are sent as string arrays. Range filters may provide `min`, `max`, and `step`; Koma sends range values as numbers in `args.filters`. Group descriptors may contain nested `filters`; Koma flattens those children into the filter bar and does not submit the group row itself.

## Settings descriptor rules

`get_settings` may return descriptors under `data.settings` or `data.items`. Koma persists only safe descriptor kinds:

- `string`
- `boolean`
- `select`
- `multiselect`
- `range`

Credential-like descriptors are treated as sensitive and are not saved by the current UI. Descriptor ids or kinds containing markers such as `password`, `token`, `cookie`, `authorization`, `api_key`, `secret`, `credential`, or `session` are blocked from normal persistence, backup, and display values.

## Image request rules

`get_image_request` may return a final image URL plus safe non-secret headers. For authenticated image requests, return a `headersRef` such as `default` and set `requiresAuth: true`; Koma resolves that reference only from host-owned header profiles. Source packages must not return raw cookies, authorization headers, API keys, passwords, tokens, or session material.

## Package archive layout

The source-repo package archive must contain exactly the required files and may
carry one fixed identity asset:

```text
manifest.json
source.wasm
icon.png (optional)
```

`icon.png`, when present, is the installed source's local identity icon. It
must be one root PNG, at most 1 MiB, with dimensions from 1 to 1024 px in each
direction. Supported layouts are 8-bit indexed palette PNG, or 8-/16-bit
grayscale, RGB, grayscale-with-alpha, and RGBA PNG. The host verifies the PNG
structure/CRC and performs an ImageKit decode before it is shown; the app does
not fetch arbitrary index icon URLs for installed-source UI. The legacy/internal
fixture layout does not allow `icon.png`.

Koma accepts picker suffixes `.koma`, `.koma-source`, `.koma-source.zip`, and `.zip`, but validation is based on archive contents rather than filename. Archive entry names must be relative, unique, non-hidden, non-symlink, and must not contain path traversal or backslashes.

Source index entries are user-configured and have this shape:

```json
{
  "id": "local.example.private",
  "name": "Private Example",
  "version": "0.1.0",
  "lang": "en",
  "nsfw": false,
  "author": "Author",
  "description": "User-owned private adapter.",
  "contentRating": "safe",
  "pkg": "sources/example/example-0.1.0.koma",
  "sha256": "<optional package sha256 hex>",
  "icon": "sources/example/icon.png",
  "minAppVersion": ""
}
```

`pkg` must be a safe relative `.koma` path resolved from the configured index document's directory. The index `icon` field is
descriptive distribution metadata; installed-source identity comes from the
validated package-owned `icon.png`, not an arbitrary remote image request. If
`sha256` is present, Koma verifies the downloaded `.koma` bytes before import.
Installs and updates downloaded from an index go through the same archive
validator as local imports.

## Compatibility notes

Package updates are explicit user actions. Koma compares installed package version with the matching configured index entry and shows update states as up-to-date, update available, index missing, check failed, checking, or not checked. Koma does not silently replace installed packages.

Source packages should keep package ids stable across versions. Downgrades, id changes, missing manifests, unsafe archive entries, network permission requests, and checksum mismatches fail closed. Disabled package state is preserved when a selected package is updated.
