# Archive Extraction / Cache Spike

## Decision

Use the HarmonyOS system ZIP module for local archive import. `zlib.decompressFile` accepts only sandbox paths and requires the input file path to end with `.zip`, so a picked `.cbz` must be copied into app cache as `archive.zip` before extraction. A picked `.zip` can use the same cache name for consistent retry and cleanup behavior.

The minimal cache layout is:

```text
context.cacheDir/
  import/
    <sanitized archive title>-<stable source hash>/
      archive.zip
      extract/
      manifest.json
```

`ArchiveExtractionService` owns the `extract/` directory and may remove/recreate it before each extraction. The picker/copy layer owns writing `archive.zip`; that layer is intentionally outside this spike because picker UI and URI copy behavior are separate from ZIP extraction.

## API Boundaries

- Import `zlib` from `@kit.BasicServicesKit`.
- Import `fileIo` from `@kit.CoreFileKit`.
- Call `zlib.decompressFile(sandboxZipPath, extractionDir)`.
- `sandboxZipPath` must be in the app sandbox and must end with `.zip`.
- `extractionDir` must already exist.
- ZIP entries containing `../` are rejected by zlib with `900003`; service-side DTO enumeration also filters unsafe relative paths.
- `fileIo.listFile(extractionDir, { recursion: true, listNum: 0 })` returns relative paths with a leading `/`. Strip the leading slash before passing entries into `ArchiveImportService`.

## DTO Flow

1. Copy selected archive URI into `cache/import/<readable-title>-<stable-hash>/archive.zip`.
2. Extract into `cache/import/<key>/extract`.
3. Enumerate extracted files recursively.
4. Normalize each listed path by replacing backslashes and removing leading `/`.
5. Keep only safe supported image paths using `ImageSortUtils`.
6. Stat each image path for `byteSize`.
7. Pass `{ path, byteSize }` entries to `buildComicFromArchive`.

The current DTO `Page.uri` remains `archivePath#entryPath`, preserving the contract already covered by `ArchiveImportService`. Runtime image loading can resolve `entryPath` through `createExtractedPagePath(extractionDir, entryPath)` when reading from cache.

## Safety / Lifecycle

- Cache key segments keep a sanitized lowercase `[a-z0-9-]` title for readability and append an 8-character stable hash.
- The hash is derived from the caller-provided cache key seed when present, otherwise from the selected archive source URI/path. This prevents cache root collisions for archives with the same basename in different locations.
- Generated zlib input and output paths reject `../` traversal.
- Re-import removes the existing extraction directory unless `cleanOutputDir` is explicitly `false`.
- Duplicate file entries are handled by the existing import builder's path de-duplication.
- Cancellation is cooperative: checked before cleanup, before zlib, and after zlib. HarmonyOS `zlib.decompressFile` does not expose a cancellation token in the documented API, so mid-inflate cancellation requires a later device-level proof or a different extraction primitive.
- Cleanup removes the cache root recursively via `fileIo.rmdir`.

## Device Spike Still Needed

This service is designed to compile against the documented API, but the following should be proven on device before wiring UI:

- Whether copying a picker-returned `.cbz` URI directly to a sandbox `.zip` path works with the chosen file API on API 23.
- Whether archives with backslash entry separators need API 21 `pathSeparatorStrategy`, or whether post-list normalization is sufficient on target devices.
- Exact behavior for filename encoding in non-UTF8 ZIPs; docs recommend UTF-8 encoded names.
