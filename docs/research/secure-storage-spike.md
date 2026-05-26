# Koma Secure Storage Spike

Date: 2026-05-26

This spike defines a future credential storage boundary for tracker OAuth tokens and other short-lived secrets. It does not implement OAuth, login UI, token storage, password storage, client secrets, network calls, or a tested secure-storage backend.

## Current Project Context

Koma currently targets HarmonyOS `6.1.0(23)` in `build-profile.json5`. The entry module requests `INTERNET`, `GET_NETWORK_INFO`, and `VIBRATE`; it does not request `ohos.permission.STORE_PERSISTENT_DATA`.

Current tracker state in `entry/src/main/ets/model/TrackerModels.ets` is limited to provider connection status and comic mapping metadata in Preferences. There are no tracker token fields today. That must remain true until a real secure storage implementation is reviewed and tested.

The backup service currently exports some existing remote server credential strings for Komga/WebDAV/OPDS from Preferences. That is legacy product behavior and is not an acceptable pattern for future tracker OAuth tokens, refresh tokens, authorization codes, API keys, client secrets, or passwords.

## HarmonyOS Storage Options

### Recommended: Asset Store Kit

Local docs: `/home/gamer/.codex/skills/harmony-next/references/JsEtsAPIReference/modules/ohos/@ohos.security.asset (关键资产存储服务).md`

Evidence from the local API reference:

- `@ohos.security.asset` is described as storage and management for short sensitive data, including password-like account/password data, token-like app credentials, and other short sensitive plaintext.
- The module starts at API version 11, which is available to this project because Koma targets API 23.
- The documented import is `import { asset } from '@kit.AssetStoreKit';`.
- Core operations exist for `asset.add`, `asset.update`, `asset.query`, and `asset.remove`, with sync variants from API 12.
- `asset.Tag.SECRET` stores the sensitive plaintext, `asset.Tag.ALIAS` is the unique index, and `asset.Tag.RETURN_TYPE` can be `asset.ReturnType.ALL` only when plaintext must be returned.
- Access controls include `asset.Tag.ACCESSIBILITY`, `asset.Tag.REQUIRE_PASSWORD_SET`, `asset.Tag.AUTH_TYPE`, and `asset.Tag.AUTH_VALIDITY_PERIOD`.
- Synchronization/export controls include `asset.Tag.SYNC_TYPE`, `asset.SyncType.NEVER`, `asset.Tag.WRAP_TYPE`, and `asset.WrapType.NEVER`.
- `asset.Tag.IS_PERSISTENT` retains assets after app uninstall and requires `ohos.permission.STORE_PERSISTENT_DATA`; Koma should not set this for user OAuth tokens.

Proposed future policy:

- Use Asset Store Kit as the first implementation candidate for tracker OAuth refresh/access tokens and private-library credentials.
- Use one Asset Store asset per `{purpose, providerId, accountKey, secretKind}` tuple.
- Set `ACCESSIBILITY` to `DEVICE_UNLOCKED` for OAuth tokens unless a later background-sync design proves a narrower need.
- Set `REQUIRE_PASSWORD_SET` to `true` for OAuth tokens; if the device has no lock credential or the Asset Store returns screen-lock mismatch, login remains unavailable with a redacted user-facing error.
- Set `AUTH_TYPE` to `NONE` for routine token refresh only if manual sync cannot tolerate per-read user authentication; otherwise consider `ANY` with `AUTH_VALIDITY_PERIOD` during a separate UX/security review.
- Set `SYNC_TYPE` to `NEVER` and `WRAP_TYPE` to `NEVER` for tracker tokens. Do not enable trusted-device/account movement until backup/restore and account-transfer behavior is separately reviewed.
- Do not set `IS_PERSISTENT`; uninstall must remove Koma credentials.
- Use non-sensitive aliases and labels. Provider/account identifiers must be normalized or hashed; no email, username, profile URL, token prefix, auth code, private server URL, or comic title in aliases or labels.

Open proof items before implementation:

- Device test `add -> query -> update -> remove -> query not found` on the target API/device.
- Verify behavior when the device has no lock screen and when locked/unlocked.
- Verify `SYNC_TYPE.NEVER` and `WRAP_TYPE.NEVER` behavior with Koma backup/export flows and any OS migration path available to the app.
- Confirm error codes map to the redacted model below without leaking Asset Store exception messages that include secret-adjacent input.

### Secondary Option: HUKS + App-Private Encrypted Blob

Local docs: `/home/gamer/.codex/skills/harmony-next/references/JsEtsAPIReference/modules/ohos/@ohos.security.huks (通用密钥库系统).md`

Evidence from the local API reference:

- `@ohos.security.huks` provides keystore capabilities for key management and cryptographic operations.
- The module starts at API version 8, so it is available at Koma API 23.
- The documented import is `import { huks } from '@kit.UniversalKeystoreKit';`.
- `huks.generateKeyItem` creates keys and the docs state key material is not returned because of the TEE key non-extraction principle.

Assessment:

- HUKS is a fallback if Asset Store Kit cannot meet product needs, or if Koma later needs encrypted structured credential bundles rather than short secrets.
- This path is more error-prone because Koma would need to design blob format, authenticated encryption parameters, key rotation, corruption handling, backup exclusion, and deletion semantics.
- It must not be used to put encrypted token blobs into normal JSON backup, Preferences, or RDB. Encrypted blobs can still become durable bearer material if copied without policy.

### Not Acceptable For Tokens: Preferences, RDB, Normal JSON Backup

Local docs: `/home/gamer/.codex/skills/harmony-next/references/JsEtsAPIReference/modules/ohos/@ohos.data.preferences (用户首选项).md`

Evidence from the local API reference:

- Preferences are lightweight persistent key-value storage for numbers, strings, booleans, and arrays.
- Preferences files are persisted under `preferencesDir`.
- The docs warn Preferences cannot guarantee process concurrency safety and can risk file damage/data loss in multi-process use.

Policy:

- Preferences may store non-secret tracker metadata such as provider id, consent status, sync enabled flag, last sync timestamp, redacted account display label, and title mappings.
- Preferences, RDB, local files, source settings, and JSON backup must not store OAuth access tokens, refresh tokens, authorization codes, passwords, API keys, client secrets, bearer headers, cookies, or encrypted token blobs.
- Koma backup import/export must keep tracker token count at zero and must not acquire any future token fields.

## Threat Model

### Token At Rest

Threats:

- Plain token copied from Preferences/RDB/files or user-exported JSON backup.
- Token recovered from app backup, device migration, cloned profile, or stale uninstall-persistent asset.
- Token left behind after logout/account disconnect.
- Token exposed by local malware or physical attacker after device unlock.

Mitigations:

- Store future OAuth tokens only behind a `CredentialSecretStore` wrapper backed by Asset Store Kit after device proof.
- Use `SYNC_TYPE.NEVER`, `WRAP_TYPE.NEVER`, no `IS_PERSISTENT`, and logout deletion by exact alias.
- Keep only non-sensitive account metadata outside Asset Store.
- Do not support tracker OAuth unless secure storage gates pass on device.

### Logs And Artifacts

Threats:

- Raw token, auth code, bearer header, cookie, user email, profile URL, private server URL, local path, or provider response appears in console logs, `.hermes-artifacts`, test fixtures, crash logs, screenshots, or source-runtime diagnostics.

Mitigations:

- Wrapper methods must never log secret input, secret length, token prefix/suffix, authorization headers, OAuth redirect query strings, or raw provider errors.
- Errors returned across the boundary use fixed reason codes and optional retry hints only.
- Artifact validation should scan for credential-shaped strings before OAuth work can merge.
- Provider fixtures must use synthetic sentinel labels such as `fixture-secret-ref`, never realistic token strings.

### Backup Exclusion

Threats:

- Manual JSON backup includes tracker tokens or encrypted blobs.
- Future OS/app backup migrates tokens contrary to user intent.
- Existing backup patterns for remote server credentials get copied into tracker work.

Mitigations:

- JSON backup schema must never include tracker token material or encrypted token blobs.
- Add a backup schema test before OAuth implementation proving no fields named like token/password/secret/code/clientSecret/authorization/cookie are exported from tracker state.
- Use Asset Store Kit `SYNC_TYPE.NEVER` and `WRAP_TYPE.NEVER`; do not set `IS_PERSISTENT`.
- Treat the current Komga/WebDAV/OPDS plain credential backup as separate technical debt, not precedent for tracker OAuth.

### Logout And Deletion

Threats:

- User disconnects provider but refresh token remains usable.
- Deleting account metadata fails after token deletion or token deletion fails after metadata deletion.
- Pending sync queue later uses stale credentials.

Mitigations:

- Logout must call `deleteToken` for every known secret kind for that provider/account before deleting account metadata.
- Logout reports success only after token deletion, in-memory token cache purge, pending sync queue purge, and account metadata deletion all complete.
- Deletion errors are redacted and retryable. UI can show disconnected only after deletion succeeds or after a documented local-forget fallback that clearly states remote revocation may still be needed.

### Crash And Report Redaction

Threats:

- Crash/recovery state serializes OAuth redirect data, provider HTTP response bodies, request headers, token endpoint errors, account identifiers, private URLs, or local paths.

Mitigations:

- Crash/report payloads may contain provider id, coarse operation, HTTP status, fixed reason code, retryable flag, and timestamp.
- They must not contain request/response bodies, query strings, headers, token endpoint payloads, raw exception messages from storage/network libraries, user identifiers, or comic-title mapping details.
- Recovery state must not include in-flight auth code or token exchange payload.

## API Boundary Proposal

The future implementation should expose one narrow credential boundary. Runtime code, provider adapters, UI, and backup code must not import `@kit.AssetStoreKit` directly.

Suggested types:

```ts
type CredentialPurpose = 'tracker_oauth' | 'private_library'
type CredentialSecretKind = 'access_token' | 'refresh_token' | 'api_key' | 'password'

interface CredentialAccountRef {
  purpose: CredentialPurpose
  providerId: string
  accountKey: string
}

interface CredentialSecretRef extends CredentialAccountRef {
  secretKind: CredentialSecretKind
}

interface CredentialWriteRequest extends CredentialSecretRef {
  secretBytes: Uint8Array
  expiresAt?: number
}

type CredentialErrorCode =
  | 'not_found'
  | 'locked'
  | 'device_security_required'
  | 'access_denied'
  | 'storage_unavailable'
  | 'corrupted'
  | 'quota_exceeded'
  | 'unsupported'
  | 'invalid_request'
  | 'unknown'

interface RedactedCredentialError {
  code: CredentialErrorCode
  retryable: boolean
  operation: 'write' | 'read' | 'delete'
  providerId?: string
}

interface CredentialSecretStore {
  writeToken(request: CredentialWriteRequest): Promise<void>
  readToken(ref: CredentialSecretRef): Promise<Uint8Array | undefined>
  deleteToken(ref: CredentialSecretRef): Promise<void>
  deleteAccount(ref: CredentialAccountRef): Promise<void>
}
```

Boundary rules:

- `secretBytes` is the only raw secret input/output and must be held in memory for the shortest possible scope.
- `readToken` returns `undefined` for not found; it must not distinguish account existence in logs.
- `deleteToken` is idempotent: missing token is success for logout cleanup.
- `deleteAccount` deletes all known secret kinds for one provider/account and must not perform broad provider-wide deletion unless explicitly requested by logout-all.
- `RedactedCredentialError` never includes raw exception message, alias, account key, token length, token prefix/suffix, or serialized request.
- Provider adapters receive raw token bytes only inside the network request construction path. They never persist, stringify, log, or return them.
- Normal Preferences/RDB/JSON backup may store only non-secret `CredentialAccountRef` metadata and user consent settings, never `CredentialWriteRequest`, `CredentialSecretRef` with secret-shaped values, or `secretBytes`.

Alias proposal:

```text
koma:v1:{purpose}:{providerId}:{accountHash}:{secretKind}
```

Rules:

- `providerId`, `purpose`, and `secretKind` come from allowlisted enums.
- `accountHash` is a stable hash of a local opaque account UUID, not a provider username/email.
- Never put provider user id, email, display name, profile URL, private server URL, token, or authorization code in the alias.

## Verification Gates Before OAuth Implementation

OAuth and tracker sync implementation remains blocked until all of these pass:

1. Asset Store Kit proof on the target API/device: write, read, overwrite, delete, missing-read, locked-device/no-lock-screen behavior.
2. Confirm no `STORE_PERSISTENT_DATA` permission is needed because `IS_PERSISTENT` is not set.
3. Confirm `SYNC_TYPE.NEVER` and `WRAP_TYPE.NEVER` are accepted for the selected Asset Store calls, or document exact fallback behavior.
4. Static review proves no tracker OAuth token/password/client-secret/auth-code fields are added to Preferences, RDB models, source settings, local files, or JSON backup schemas.
5. Backup export/import tests prove tracker token material and encrypted credential blobs are absent.
6. Logout tests prove token deletion, metadata deletion, pending queue purge, and memory cache purge.
7. Redaction tests prove logs/artifacts/crash reports do not include tokens, auth codes, bearer headers, cookies, provider profile URLs, private server URLs, local paths, or raw provider responses.
8. Provider OAuth flow decision is documented per provider: Authorization Code + PKCE, unsupported, or backend proxy. Password grant is disallowed.
9. No OAuth client secret is embedded in the app or artifacts.
10. Provider sandbox/test account plan uses synthetic credentials outside repository/artifacts.
11. Redirect/deep-link proof shows no authorization code, token, or state parameter is logged.
12. Manual sync-only launch gate is reviewed; background sync needs a separate scheduling/privacy design.

## Spike Result

This spike recommends Asset Store Kit for the first real secure-storage implementation, with HUKS reserved as a fallback for a later encrypted-blob design. No secure storage is implemented by this document. No real credentials were added.
