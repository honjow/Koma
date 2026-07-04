# Koma Privacy And Permissions

Koma is a private manga bookshelf and reader for local files, self-hosted libraries, and user-installed source packages. The app should stay honest about what it can access, when network requests happen, and where sensitive data is stored.

## Data Sources

- Local archive and folder imports are user-driven. Koma only reads file or folder URIs returned by the system picker.
- Komga, OPDS, and WebDAV requests are sent only to servers configured by the user.
- Source packages are installed by the user and are not bundled as a public source index. Package network access is rejected unless the manifest declares it and the runtime policy accepts it.
- Tracker services such as AniList or MyAnimeList are optional. Koma must not upload reading progress until the user connects an account and chooses or confirms a mapping.

## Permissions

- `ohos.permission.INTERNET` is used for private library servers, source runtime network requests, tracker APIs, and remote image loading.
- `ohos.permission.GET_NETWORK_INFO` is used for network-aware behavior such as Wi-Fi-only download checks.
- `ohos.permission.VIBRATE` is used only for local interaction feedback.
- Notification delivery is requested from Settings before Koma publishes download or library update notifications. Koma must report disabled or unavailable notification state honestly.
- Local import does not request broad media or filesystem permissions. The picker grants access to selected files or folders.

## Credentials And Secrets

- Private library credentials, tracker tokens, cookies, API keys, and OAuth authorization data must not be stored in plain JSON preferences, RDB rows, backups, logs, screenshots, or `.hermes-artifacts`.
- Secure storage is the default location for account tokens. Logout or account removal must clear the secure entry and local account metadata.
- Build signing material and local build profiles are machine-local and must not be committed.

## Backups

- Plain backups may include library metadata, categories, reading progress, source package metadata, settings, and download queue state.
- Plain backups must not include passwords, API keys, bearer tokens, cookies, OAuth codes, or decrypted secure-storage payloads.
- Encrypted backups protect the exported payload with a user-provided passphrase. The passphrase must not be saved.
- Credential export, if ever added, must be a separate explicit design with provider-specific consent and tests.

## Logs And Artifacts

- Logs may include stable status codes, sanitized source keys, counts, and operation names.
- Logs must not include raw tokens, authorization headers, private server URLs with query secrets, user emails, local file paths not needed for restore, or raw provider responses.
- Test fixtures and `.hermes-artifacts` follow the same redaction rule as app logs.

## Release Checklist

- Settings exposes a visible Privacy and Permissions entry under About.
- `scripts/check-public-build-profile.sh --staged` passes before commits that touch build profiles.
- Static tests cover token redaction boundaries, notification permission state, source package network permission checks, and backup secret exclusion.
- Signed install smoke verifies the release and debug build lanes use `com.honjow.koma`.
