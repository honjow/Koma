# Local Import Picker Research

Date: 2026-05-21
Device target: `192.168.50.103:12345`
Project API: min API 12, target API 23, `Release23`

## Verdict

Koma can ship local import with three separate entry points:

1. Images: use `photoAccessHelper.PhotoViewPicker` for single or multiple images.
2. ZIP/CBZ: use `picker.DocumentViewPicker` filtered to `.zip,.cbz`, then copy/read the returned file URI through `@kit.CoreFileKit` file APIs.
3. Folder: expose as best-effort only. `DocumentViewPicker` has `DocumentSelectMode.FOLDER`, but it requires `SystemCapability.FileManagement.UserFileService.FolderSelection`; product UX must fall back to ZIP/CBZ or multiple-image selection when folder selection is unavailable or fails.

Do not request broad media/file permissions for these flows. The picker returns user-granted URIs.

## Current Project Context

- `AppScope/app.json5` declares `targetAPIVersion: 23`, `minAPIVersion: 12`, `apiReleaseType: "Release23"`.
- `build-profile.json5` uses SDK `6.1.0(23)`.
- `entry/src/main/module.json5` currently requests only network and vibration permissions. No media/file permission is declared.

## Official Offline Evidence

Evidence was taken from the local HarmonyOS reference under `/home/gamer/.codex/skills/harmony-next/references/JsEtsAPIReference`.

- `modules/ohos/@ohos.file.picker (选择器).md`: `@ohos.file.picker` wraps `DocumentViewPicker`, `AudioViewPicker`, and deprecated `PhotoViewPicker`. It must be called from a UIAbility to raise the picker UI.
- Same file: `DocumentViewPicker.select(option?: DocumentSelectOptions): Promise<Array<string>>` lets the user select one or more files and returns document URI strings.
- Same file: `DocumentSelectOptions.fileSuffixFilters` filters by suffix, e.g. descriptions plus `.zip,.cbz`; no MIME table is needed for CBZ.
- Same file: `DocumentSelectMode` has `FILE`, `FOLDER`, and `MIXED`; `selectMode` requires `SystemCapability.FileManagement.UserFileService.FolderSelection`.
- Same file: folder selection is limited by device capability; API 23 removes the directory-count limit, but capability is still required.
- `types/classes/Class (PhotoViewPicker).md`: `photoAccessHelper.PhotoViewPicker.select` chooses one or more images/videos and returns `PhotoSelectResult`.
- Same file: returned `photoUris` have permanent authorization and can be used through `photoAccessHelper.getAssets`.
- `types/classes/Classes (其他).md`: `PhotoSelectOptions.maxSelectNumber` supports up to 500; default is 50.
- `modules/ohos/@ohos.file.fs (文件管理).md`: `fs.open`/`fs.openSync` support opening file URIs; `fs.stat` supports URI from API 22. `fs.listFile` is for sandbox paths, not arbitrary returned document directory URIs.
- `guides/module.json5配置文件.md`: `fileAccess` ExtensionAbility lets apps provide files/folders to file-manager apps, but third-party configuration is not effective and is system-app only. It is not a Koma import solution.
- `topics/misc/属性.md`: `fileAccess(true)` is a Web component property for allowing the Web component to access in-app filesystem paths. It is unrelated to native import picker capability.

## Feasibility By Import Type

### Single or Multiple Images

Feasible and recommended for loose image import.

Use:

```ets
import { photoAccessHelper } from '@kit.MediaLibraryKit';

const options = new photoAccessHelper.PhotoSelectOptions();
options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
options.maxSelectNumber = 500;

const picker = new photoAccessHelper.PhotoViewPicker();
const result = await picker.select(options);
const uris: string[] = result.photoUris;
```

Implementation notes:

- Show this as "Import images".
- Preserve returned URI order only as picker order; Koma should still sort by display name or extracted page number when building a chapter.
- To decode/read, either open the media URI read-only with `fileIo/fs.open`, or resolve assets with `photoAccessHelper.getAssets` when metadata is needed.
- This flow is user-driven and should not need `READ_MEDIA` style broad permission.

### ZIP/CBZ Files

Feasible and recommended for comic archives.

Use:

```ets
import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';

const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
const options = new picker.DocumentSelectOptions();
options.selectMode = picker.DocumentSelectMode.FILE;
options.fileSuffixFilters = ['Comic archives(.zip, .cbz)|.zip,.cbz'];
options.maxSelectNumber = 100;

const documentPicker = new picker.DocumentViewPicker(context);
const uris: string[] = await documentPicker.select(options);
```

Implementation notes:

- Copy each selected URI into Koma's sandbox before archive indexing. This avoids relying on long-term behavior of document URI grants and gives the ZIP reader a sandbox path if the decompressor requires one.
- Use `@kit.CoreFileKit` `fs.open(uri, fs.OpenMode.READ_ONLY)` or equivalent file IO to stream/copy into app storage.
- CBZ is just ZIP by convention. Filtering by suffix is enough for picker UX; content sniffing should still validate ZIP magic before import.

### Folder / Directory

Conditionally feasible, not reliable enough as the only import path.

Use only as a best-effort action:

```ets
import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';

const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
const options = new picker.DocumentSelectOptions();
options.selectMode = picker.DocumentSelectMode.FOLDER;
options.maxSelectNumber = 1;

const documentPicker = new picker.DocumentViewPicker(context);
const folderUris: string[] = await documentPicker.select(options);
```

Boundary:

- `DocumentSelectMode.FOLDER` requires `SystemCapability.FileManagement.UserFileService.FolderSelection`.
- The target device exposes `SystemCapability.FileManagement.UserFileService = true`, but the command-line capability dump did not show the exact `UserFileService.FolderSelection` key. Because no manual picker interaction was allowed, real folder selection success was not verified.
- Even if a folder URI is returned, `fs.listFile` documents sandbox paths, not arbitrary external document folder URIs. The implementation must verify whether returned folder URI can be opened/listed on device. If not, copy-by-folder is blocked and UX must ask for ZIP/CBZ or multiple image files.

Recommended UX:

- Primary: "Import archive" for CBZ/ZIP.
- Secondary: "Import images" for loose pages.
- Optional/advanced: "Import folder", hidden behind runtime capability/smoke result, with graceful failure text that tells the user to select images or zip the folder.

## Device Probe

Non-interactive probe on `192.168.50.103:12345`:

- `const.ohos.apiversion`: `23`
- `const.product.devicetype`: `tablet`
- exposed syscaps include:
  - `SystemCapability.FileManagement.UserFileService = true`
  - `SystemCapability.FileManagement.PhotoAccessHelper.Core = true`
  - `SystemCapability.FileManagement.AppFileService.FolderAuthorization = true`
- exact `SystemCapability.FileManagement.UserFileService.FolderSelection` was not present in the grep output.

This is enough to proceed with image and ZIP/CBZ picker implementation. Folder import remains a runtime/device validation item because docs require a more specific capability than the observed generic `UserFileService`.

## Implementation Decision

For Lane 1C, implement import plumbing in this order:

1. `DocumentViewPicker` archive flow for `.cbz,.zip`, copy URI to sandbox, then feed Lane 1B archive reader.
2. `PhotoViewPicker` image flow, return `photoUris`, derive page list with natural sort, and copy/cache thumbnails as needed.
3. Folder flow only after a dedicated interactive smoke test proves returned folder URIs can be enumerated or copied on the actual target class.

Do not implement `fileAccess` ExtensionAbility for Koma. It is for system/file-manager integration and third-party configuration is documented as ineffective.

## Lane 1H Spike Update

`entry/src/main/ets/import/LocalImportCoordinator.ets` now implements the archive boundary:

- `createArchiveDocumentSelectOptions()` uses `Comic archives(.zip, .cbz)|.zip,.cbz`.
- After build validation, the implementation intentionally omits `selectMode`: document picker defaults to file selection, while setting `selectMode` explicitly triggers a FolderSelection syscap warning even for `FILE`.
- `pickArchiveUris(context)` constructs `DocumentViewPicker` with `UIAbilityContext`.
- `copyPickedArchiveUriToSandbox(sourceUri, sandboxZipPath)` opens the picker URI read-only via `fileIo.open`, opens sandbox `archive.zip` for overwrite, and copies by file descriptor using `fileIo.copyFile`.
- `importPickedArchive()` creates `cache/import/<archive>-<hash>/archive.zip`, copies the selected URI there, then calls `ArchiveExtractionService.extractArchive`.

The Import page is wired to launch this flow from the CBZ/ZIP button, but automated validation intentionally does not click through the system picker. A real file selection remains a manual QA proof point: select a small `.cbz` and `.zip`, confirm `archive.zip` appears in app cache, and confirm extraction produces image entries.
