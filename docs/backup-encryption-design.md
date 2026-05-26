# Backup Encryption Design

This document specifies the real encrypted backup path. Current code keeps the legacy schema v3 unencrypted JSON export/import path and adds a separate encrypted envelope v1 path for schema v4 backup payloads.

## Current State

- Current unencrypted exports are schema v3 JSON with explicit `encryption.state = "unencrypted"` and `algorithm = "none"`.
- Current encrypted exports wrap a schema v4 backup JSON payload in envelope v1 using PBKDF2-HMAC-SHA-256 and AES-256-GCM.
- Current import preview parses unencrypted JSON before restore and shows schema, export time, encryption state, and safe counts. Encrypted preview shows only public envelope metadata until passphrase authentication succeeds.
- Credential-like source settings are filtered before persistence and backup. This remains required for encrypted backups because encryption is not a substitute for safe export policy.

## Future Envelope

Encrypted backups use a new outer envelope instead of overloading the current unencrypted document. The first encrypted format is a schema v4 payload wrapped by envelope version 1:

```json
{
  "kind": "koma.backup.encrypted",
  "envelopeVersion": 1,
  "contentSchemaVersion": 4,
  "createdAt": 1760000000000,
  "algorithm": "AES-256-GCM",
  "kdf": {
    "id": "PBKDF2-HMAC-SHA-256",
    "iterations": 600000,
    "salt": "base64url-16-or-32-random-bytes"
  },
  "nonce": "base64url-12-random-bytes",
  "tag": "base64url-16-byte-gcm-tag",
  "aad": {
    "kind": "koma.backup.encrypted",
    "envelopeVersion": 1,
    "contentSchemaVersion": 4,
    "algorithm": "AES-256-GCM",
    "kdfId": "PBKDF2-HMAC-SHA-256"
  },
  "payload": "base64url-ciphertext"
}
```

Rules:

- `payload` is the encrypted canonical JSON bytes for the future schema v4 backup document.
- AES-GCM associated data is the canonical UTF-8 JSON encoding of `aad`. Import must rebuild the canonical AAD from parsed metadata and compare it with the serialized field before decrypting.
- `createdAt`, `salt`, `nonce`, `tag`, and `payload` are public envelope metadata. Library rows, reading progress, server URLs, source index URL, source package manifests/bytes, source settings, and reader settings stay inside the encrypted payload.
- `salt` must be unique per export and generated with a CSPRNG. `nonce` must be unique per derived key and generated with a CSPRNG; never reuse a nonce for the same passphrase-derived key.
- `tag` authentication failure is a hard import failure. The app must not write any restored data until the tag verifies and the decrypted schema validates.
- `algorithm` and `kdf.id` are closed allowlists. Unknown values are unsupported, not silently downgraded.
- KDF parameters must be stored in the envelope. Iterations should be calibrated before implementation on target devices, with 600,000 PBKDF2-HMAC-SHA-256 iterations as the initial floor unless device QA proves it unusable. Argon2id may replace PBKDF2 only after a reviewed HarmonyOS-compatible implementation exists and has memory/cancellation behavior covered by tests.

## Passphrase UX

No passphrase UI should be added until the crypto implementation and tests exist. When added:

- Export requires entering a passphrase twice in the same flow before writing a file.
- The confirmation field must match exactly. Mismatch blocks export before any backup document is serialized to a picker target.
- The app must explain that Koma cannot recover a lost passphrase. There is no escrow, reset, or cloud recovery.
- Empty passphrases are disallowed. A minimum length floor should be enforced, but the UI should allow long passphrases and password-manager paste.
- Passphrases are never saved in preferences, RDB, backup files, artifacts, logs, crash reports, or analytics.
- The passphrase value should remain only in memory long enough to derive the key and run encryption/decryption. Clear mutable buffers where the platform API allows it.
- Import asks for the passphrase only after detecting an encrypted envelope. Wrong passphrase, wrong file, and tampering should share a neutral user-facing failure category so the app does not reveal which part failed.
- The restore confirmation stays separate from decryption. Successful decryption may show a preview, but the user must still explicitly confirm restore before data is written.

## Import Preview Boundary

Unencrypted v1/v2/v3 JSON:

- The current preview behavior remains valid: schema, export time, unencrypted state, and counts can be parsed before restore.

Encrypted envelope v1:

- Before decryption, preview may show only public envelope fields: encrypted backup marker, envelope version, content schema version, export time if present, algorithm id, KDF id, and whether the file shape is parseable.
- Before decryption, preview must not show library item counts, reading progress counts, source package counts, source settings counts, server URLs, source index URL, titles, paths, or any settings derived from the encrypted payload.
- After passphrase entry and successful authentication, the app may build the same safe counts preview from the decrypted schema v4 payload.
- If decryption or authentication fails, no decrypted preview is available and no restore action is enabled.

## Exclusion And Redaction

Encrypted backup support does not change the export allowlist. The backup document must continue to be built from explicit domains, not from broad preferences or database dumps.

Allowed in encrypted payload when already supported by backup schema:

- Library metadata and local identifiers needed for restore.
- Reading progress.
- Reader/settings preferences.
- Installed source package manifests and package bytes.
- Sanitized non-secret source settings.
- Remote server non-secret configuration required to rebuild connection rows.

Excluded unless a separate secure storage export design is implemented and reviewed:

- OAuth access tokens, refresh tokens, authorization codes, client secrets, session cookies, API keys, Basic auth material, WebDAV credentials, Komga session tokens, OPDS credentials, and any raw `Authorization` or `Cookie` header.
- Password fields from source descriptors or provider settings.
- Raw request/response bodies, signed image URLs, private library URLs with query secrets, local filesystem paths not required for restore, crash logs, diagnostics, and artifact paths.

If future secure credential export is supported, it must be a distinct opt-in design with provider-specific consent, secure storage read/export APIs, revocation guidance, and tests proving credentials do not enter logs or unencrypted artifacts. It must not be added implicitly because backup encryption exists.

## Migration Path

- Keep importing v1/v2/v3 unencrypted JSON for compatibility.
- Keep exporting v3 unencrypted JSON for compatibility. Encrypted export writes schema v4 only inside the authenticated ciphertext.
- Encrypted export writes `kind = "koma.backup.encrypted"`, `envelopeVersion = 1`, and encrypted `contentSchemaVersion = 4`.
- Import detection order:
  1. Parse JSON.
  2. If `kind = "koma.backup.encrypted"`, use encrypted flow and require passphrase before payload preview or restore.
  3. Otherwise, treat as legacy unencrypted backup and apply existing v1/v2/v3 validation.
- A future migration affordance may offer "export encrypted copy" after a successful legacy import, but it must not rewrite or delete the user's original file.
- Schema v4 should preserve v3 domain semantics first, then add any encrypted-only metadata inside the payload only when needed.

## Verification Gates

Implementation cannot ship until these gates exist and pass:

- Known-answer tests for KDF, AES-GCM encryption, AES-GCM decryption, AAD binding, and envelope canonicalization.
- Round-trip tests proving encrypted export followed by import restores the same schema payload.
- Wrong-passphrase tests proving authentication fails, no partial plaintext preview is returned, no restore writes occur, and the error is neutral.
- Tamper tests for changed `payload`, `tag`, `nonce`, `salt`, `algorithm`, `kdf`, `contentSchemaVersion`, and `aad`.
- Legacy tests proving v1/v2/v3 unencrypted imports still work and current v3 exports still honestly label themselves unencrypted until encrypted export is actually enabled.
- Static or integration checks proving backup files, logs, artifacts, dialog strings, and exceptions do not contain passphrases, OAuth tokens, cookies, authorization headers, raw credentials, or decrypted payload snippets.
- Picker/export tests proving plaintext schema v4 is never written to the destination before encryption succeeds.
- Device performance tests for KDF latency, cancellation behavior, memory pressure, and repeated wrong-passphrase attempts.
