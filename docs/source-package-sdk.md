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

`id`, `name`, and `version` are required. `id` must be non-empty and at most 96 characters. `capabilities.operations` is optional and may declare supported runtime operations using operation names such as `get_home`, `get_filters`, or `get_settings`; Koma normalizes these into a bounded display summary and ignores unknown operation names. Koma currently rejects packages that request network access, marketplace behavior, built-in-source behavior, remote install behavior, unsafe archive entries, missing WASM, or checksum mismatches.

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

`get_filters` may return descriptors under `data.filters`. Koma supports `text`, `boolean`/`check`, `select`, `sort`, `multiselect`/`multi-select`, `range`, and `group` descriptors. `select`, `sort`, and `multiselect` filters may provide `options` as strings or objects with `id` plus `label`/`name`; Koma displays labels but sends normalized ids in `args.filters`. Multi-select values are sent as string arrays. Range filters may provide `min`, `max`, and `step`; Koma sends range values as numbers in `args.filters`.

## Settings descriptor rules

`get_settings` may return descriptors under `data.settings` or `data.items`. Koma persists only safe descriptor kinds:

- `string`
- `boolean`
- `select`
- `multiselect`
- `range`

Credential-like descriptors are treated as sensitive and are not saved by the current UI. Descriptor ids or kinds containing markers such as `password`, `token`, `cookie`, `authorization`, `api_key`, `secret`, `credential`, or `session` are blocked from normal persistence, backup, and display values.

## Package archive layout

The source-repo package archive must contain exactly:

```text
manifest.json
source.wasm
```

Koma accepts picker suffixes `.koma`, `.koma-source`, `.koma-source.zip`, and `.zip`, but validation is based on archive contents rather than filename. Archive entry names must be relative, unique, non-hidden, and must not contain path traversal or backslashes.

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
  "icon": "",
  "minAppVersion": ""
}
```

`pkg` may be relative to the configured index URL. Installs and updates downloaded from an index go through the same archive validator as local imports.

## Compatibility notes

Package updates are explicit user actions. Koma compares installed package version with the matching configured index entry and shows update states as up-to-date, update available, index missing, check failed, checking, or not checked. Koma does not silently replace installed packages.

Source packages should keep package ids stable across versions. Downgrades, id changes, missing manifests, unsafe archive entries, network permission requests, and checksum mismatches fail closed. Disabled package state is preserved when a selected package is updated.
