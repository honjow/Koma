# Koma Source Settings/Auth Boundary

This document defines a design/tooling-only boundary for future source package
settings, authentication declarations, and secret references. It does not enable
product UI, real login, credential storage, cookie handling, HTTP, or network
runtime behavior.

The current source runtime remains closed:

- `permissions.network` must be `false`.
- `koma_host.http_request` must not appear in permissions or required imports.
- The only current host imports are `koma_host.log` and
  `koma_host.check_cancel`.
- Login/logout/status/session operations are schema examples only and must not
  be executable.

## Settings Schema

A future source package may declare settings metadata so host tooling can inspect
the shape before any product UI exists. The declaration is not a persisted user
settings file and must not contain user values.

Supported field types:

- `string`: plain non-secret text. Optional constraints include `minLength`,
  `maxLength`, and `pattern`.
- `enum`: one selected string from `options`. A default must be one of the
  options.
- `bool`: boolean value with an optional boolean default.
- `number`: floating-point numeric value with optional `min`/`max`.
- `int`: integer numeric value with optional integer `min`/`max`.
- `secret`: a host-owned secret reference placeholder, never an inline secret
  value.

Common field metadata:

- `key`: stable opaque key, using lower camel case or snake case.
- `label`: short human-readable label for future UI.
- `description`: optional human-readable explanation.
- `required`: boolean.
- `default`: optional default for non-secret fields only.
- `constraints`: optional validation hints for compatible field types.
- `secretRef`: for `secret` fields only, an object such as
  `{ "id": "accountPassword", "purpose": "password" }`.

Secret fields must not include `default`, `value`, `sample`, `example`,
`cookie`, `token`, `password`, or authorization header content. Non-secret
settings must not be used to smuggle secrets.

## Secret Ownership

Secrets are host-owned. A source manifest can declare the need for a secret slot
or reference by ID, but the source package and fixture corpus must not contain
raw credentials. Host-owned storage/session state is the only future persistence
model considered by this boundary.

Tooling reports and logs must redact secret-shaped values. Validators should
report paths and categories, not leaked raw values.

Denied leak classes include:

- raw passwords, tokens, API keys, bearer tokens, authorization headers, cookies,
  and set-cookie values.
- raw local paths, picker URIs, content URIs, app-private paths, cache/files
  paths, and artifact directories.
- source responses or logs that contain credential material.

## Auth Model

The future auth model can name these concepts:

- `login`: establishes host-owned session/secret state.
- `logout`: clears host-owned session/secret state.
- `status` or `session`: checks whether host-owned auth state is available,
  expired, or needs user action.

In the current lane these concepts are metadata only. If represented in JSON,
each operation must declare `designOnly: true` and `runtimeEnabled: false`.
Operations must not include executable function names, exported symbols,
endpoints, HTTP request shapes, scripts, or runnable handlers.

## Credential And Cookie Policy

Future HTTP-enabled sources must treat credentials as host-private data. Raw
cookies, authorization headers, bearer tokens, passwords, app-private paths, and
picker URIs must not appear in source responses, logs, reports, or persisted
source settings.

The host may later inject scoped credential handles into a request pipeline, but
source code should only receive opaque references and structured auth errors.
Sources must not own cookie jars or serialize session state.

## Network Relationship

Settings/auth declarations may include a future requirement such as
`requiresFutureHttp: true`, but current fixtures and validators must keep
`network=false`. Any attempt to set `network=true` or declare
`koma_host.http_request` in the current runtime manifest is policy drift and must
be rejected.

The HTTP host import contract remains documented separately under
`../host-imports/`. This boundary only describes metadata and failure shapes.

## Structured Errors

Future auth-capable source responses should use structured errors instead of raw
service responses. Candidate codes:

- `AUTH_REQUIRED`
- `AUTH_EXPIRED`
- `BAD_CREDENTIALS`
- `RATE_LIMITED`
- `ACCOUNT_LOCKED`
- `HOST_CREDENTIAL_UNAVAILABLE`
- `NETWORK_REQUIRED_BUT_DISABLED`

Error details must remain non-secret. They can include a stable `reason`,
`retryAfterSeconds`, or `action` hint, but must not include cookies, tokens,
passwords, authorization headers, raw URLs with credentials, local paths, or
app-private paths.

## Local Evidence

`settings-auth.example.json` is a non-executable example. The static fixture
validator lives at `validate-settings-auth-fixtures.py` and checks local JSON
only. It performs no network I/O, does not invoke WAMR, and writes its report
under the supplied artifact directory.
