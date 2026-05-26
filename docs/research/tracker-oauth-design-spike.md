# Koma 公共追踪服务 OAuth 设计 Spike

日期：2026-05-26

本设计只定义未来公共追踪服务接入的产品与架构边界，不实现 OAuth、登录 UI、网络请求、token 字段、凭据存储或同步状态。Koma 当前仍应展示诚实的未连接/计划中状态，直到安全存储、用户同意、provider 审核和端到端验证完成。

目标 provider：

- AniList
- MyAnimeList (MAL)
- Kitsu
- MangaUpdates
- Bangumi

## 结论

推荐后续实现顺序：

1. **AniList**
   - GraphQL API 覆盖 manga 搜索、媒体详情、用户媒体列表和进度 mutation，适合先做完整读写同步 spike。
   - 风险是第三方 API 可用性、限流、OAuth 注册和移动端 redirect 审核，需要实现前再次验证。
2. **MyAnimeList**
   - 官方 v2 REST API 覆盖 manga search/detail/user manga list 更新，用户价值高。
   - OAuth 2.0 + PKCE 对移动端更合适，但注册、redirect URI、字段授权和错误处理要单独验证。
3. **Bangumi**
   - 中文用户价值高，API 和 OAuth 能力公开，条目类型可覆盖书籍/漫画。
   - 需要重点验证条目/章节粒度、收藏状态与 Koma 漫画阅读进度之间的语义差异。
4. **Kitsu**
   - JSON:API 模型清晰，manga/library entries 可映射。
   - 当前公开文档仍强调 password grant；Koma 不应实现收集用户密码的 OAuth flow，除非 provider 提供可接受的授权码/PKCE 路径并完成安全评审。
5. **MangaUpdates**
   - 对 manga 元数据和状态追踪有价值，但公开 API/认证/写入能力的官方文档可发现性弱于前三者。
   - 先作为只读元数据匹配候选，后续再验证是否支持安全、合规的用户列表写入。

## Provider 能力矩阵

| Provider | 公共元数据搜索 | 用户列表读取 | 用户进度写入 | OAuth/API 可行性 | Koma 首版建议 |
| --- | --- | --- | --- | --- | --- |
| AniList | 高；GraphQL `Media` 可查 manga | 高；用户 media list | 高；list entry mutation 可表达 status/progress/score | OAuth 2.0；官方 GraphQL API；实现前复核授权方式、redirect、限流和近期可用性 | 第一优先，做完整 sync contract spike |
| MyAnimeList | 高；v2 REST manga endpoints | 高；user manga list | 高；update user manga list item | OAuth 2.0；移动端优先评估 Authorization Code + PKCE；需要 app 注册 | 第二优先，适合做 REST adapter |
| Bangumi | 中高；subject/search 覆盖书籍类条目 | 中高；collection API | 中；collection 状态/评分可写，章节页进度需验证 | OAuth 2.0；API 文档和 OpenAPI 公开；必须遵守 User-Agent 建议 | 中文生态优先 provider，先做条目级状态 |
| Kitsu | 中高；JSON:API manga resources | 中；library entries | 中；library entry progress/status | OAuth 2.0 文档存在，但 password grant 不符合 Koma 移动端安全边界 | 暂缓写入；只在可用授权码/PKCE 明确后推进 |
| MangaUpdates | 中高；manga 数据匹配价值高 | 待验证 | 待验证 | 官方 API 文档和认证/写入能力需要进一步确认 | 先做只读匹配调研，不承诺同步 |

能力说明：

- “用户进度写入”只代表 provider 可能存在写入口，不代表 Koma 当前可实现。
- Koma 不追踪内容来源，不上传页面 URL、文件路径、私有库 server URL 或本地文件名。
- Provider 只接收用户明确映射后的作品条目、章节/卷进度、状态和可选评分。

## API / OAuth 可行性备注

### AniList

已知形态：

- 官方 API 是 GraphQL，主 endpoint 为 `https://graphql.anilist.co`。
- 公共 metadata 可在未授权下查询；用户 list 和 mutation 需要 OAuth access token。
- Manga progress 常见粒度是章节数，不能表达 Koma 的页内进度。

实现前验证：

1. App 注册、redirect URI、移动端回跳是否支持 HarmonyOS。
2. Authorization Code + PKCE 是否可用；若只能用 implicit flow，需要安全评审后再决定。
3. 当前 API 可用性、限流头、错误码和 429 backoff 策略。
4. `SaveMediaListEntry` 对 manga 的 `progress`、`status`、`score` 语义。

### MyAnimeList

已知形态：

- 官方 v2 REST API 提供 manga 搜索/详情和用户 manga list 读写。
- OAuth 2.0 需要 app 注册；移动端应使用授权码 + PKCE，不把 client secret 放入 App。
- MAL 的进度通常是 chapter/volume，不表达页内进度。

实现前验证：

1. OAuth redirect URI 规则和 HarmonyOS app link/custom scheme 可用性。
2. Token refresh 行为、撤销/过期错误码、scope 最小集合。
3. User manga list update endpoint 的字段覆盖：status、chapters、volumes、score、reread。
4. API quota 和 User-Agent / client identification 要求。

### Bangumi

已知形态：

- Bangumi API 公开 repo 和 OpenAPI 文档存在，并要求关注 User-Agent 建议。
- OAuth 2.0 可用于用户收藏/条目相关操作。
- 条目类型和收藏状态与 Koma 的漫画阅读进度不是一一对应，需要 provider adapter 做语义降级。

实现前验证：

1. OAuth app 注册流程、redirect、token refresh 和 scope。
2. 书籍/漫画 subject 搜索质量，中文/日文/别名匹配策略。
3. Collection 写入字段是否能表达 reading/completed/on-hold/dropped/planning。
4. 是否存在章节级/卷级进度；若没有，Koma 只同步条目状态和评分。

### Kitsu

已知形态：

- Kitsu JSON:API 文档公开；manga 和 library entries 可表达媒体与用户库。
- 文档显示 OAuth2 token endpoint，但主要示例是 password grant。
- Koma 不允许收集用户 Kitsu 邮箱/用户名和密码。

实现前验证：

1. 是否存在对第三方移动 App 可接受的 authorization code + PKCE flow。
2. Library entry create/update 字段：status、progress、rating、reconsume count。
3. JSON:API pagination、include 和 filtering 对 manga search 的实际表现。
4. 若只能 password grant，则 provider 标记为 unsupported for login。

### MangaUpdates

已知形态：

- MangaUpdates 对漫画别名、状态和外部匹配有价值。
- 公开 API 的认证、用户列表读取/写入能力和长期稳定性需要单独确认。

实现前验证：

1. 官方 API 文档入口、认证方式、app 注册或 API key 规则。
2. 是否提供用户 series list、status、chapter progress 写入。
3. Rate limit、商业/第三方客户端使用条款。
4. ID 和 URL ID 映射规则，避免把错误 provider ID 写入 Koma mapping。

## 凭据和存储边界

当前 App 不新增任何 token/password/credential 字段。

未来实现必须先完成独立安全设计：

- 使用系统级安全存储或等价能力保存 refresh token/access token；普通 JSON/RDB/Preferences 不能存 token。
- App 内不保存 provider 密码；不支持 Resource Owner Password Credentials flow。
- 客户端不内置 OAuth client secret；移动端只能使用 public client + PKCE，或由受控后端代理完成 confidential client 流程。
- 用户必须逐 provider 明确同意连接、授权 scope、同步方向和上传字段。
- 退出登录必须清除安全存储中的 token、内存 token、pending sync 队列和 provider account metadata。
- 日志、artifact、crash report、analytics 不得包含 token、授权码、用户名邮箱、provider profile URL、私有库 URL、本地文件路径或漫画标题到 provider 的映射明细。

建议未来模型边界：

| 类型 | 可存字段 | 禁止字段 |
| --- | --- | --- |
| `TrackerProviderConfig` | provider id、display name、capability flags、docs/version note | client secret、token endpoint response |
| `TrackerAccount` | provider id、provider user id hash/display name opt-in、connectedAt、lastSyncAt nullable、sync enabled bool | access token、refresh token、password、authorization code |
| `TrackerTitleMapping` | local comic id、provider id、provider title id、confidence、userConfirmed bool、createdAt | local file path、page image URL、private source server URL |
| `TrackerSyncRecord` | comic id、provider id、last attempted at、result code、redacted error category | raw request/response, token, manga title if not needed |

## Sync Contract

### Identity mapping

Koma must never auto-upload progress for a comic until it has a confirmed provider identity.

Mapping states:

| State | Meaning | Allowed sync |
| --- | --- | --- |
| `unmapped` | No provider candidate selected | None |
| `candidate` | Local title matched search result but user has not confirmed | None |
| `confirmed` | User selected provider entry | Manual sync and future background sync allowed |
| `rejected` | User rejected a candidate | None; avoid suggesting same candidate unless reset |
| `stale` | Provider entry disappeared or changed incompatibly | Stop writes; ask user to remap |

Matching inputs:

- Local comic title, alternative titles if user entered them, author if available, release year if available.
- Existing remote metadata from Komga/OPDS/WebDAV only if it is already user-owned metadata and not a private server URL.
- No local file path, folder name, page image URL or private library URL leaves the device.

Provider mapping key:

```text
tracker:{providerId}:title:{providerTitleId}
```

Koma local key remains the existing local/remote comic id. The tracker mapping is an overlay and must not become the canonical comic id.

### Progress model

Koma reader progress has finer granularity than most trackers:

```text
comicId
chapterId
chapterNumber? / chapterSortKey?
pageIndex
pageCount
completedChapter bool
updatedAt
```

Provider progress should be derived as:

| Koma event | Provider chapter progress | Provider status candidate |
| --- | --- | --- |
| Opened but no completed chapter | No write | Keep existing or `reading` only if user explicitly starts tracking |
| Completed chapter N | Set progress to max(existing remote, N) unless conflict policy says ask | `reading` |
| Completed final known chapter | Set progress to final chapter count if known | Ask before setting `completed` unless user enabled auto-complete |
| User marks completed in Koma | Set provider status completed and progress final count if known | `completed` |
| User removes local comic | No provider delete | No status change |

Page progress remains local-only. If a provider cannot store page progress, Koma may show “page progress stays on this device” in future settings, but it must not imply remote page sync.

### Conflict policy

Default policy: **provider wins for higher completed chapter count; Koma asks for destructive/lower changes**.

Rules:

- If local completed chapter > remote progress, manual sync may upload local progress after user confirmation or account-level opt-in.
- If remote progress > local completed chapter, Koma may offer to advance local reading position to the start of that chapter; it must not silently skip local pages.
- If statuses conflict:
  - remote `completed` vs local not final: ask.
  - local `dropped/on-hold` concept is not currently part of core Koma reading model; do not infer it from inactivity.
  - provider `planning` should not overwrite local reading progress.
- Timestamps are advisory only because provider clocks and Koma local clocks may differ.
- Failed writes must be retryable and idempotent; never queue duplicate increments.

### Manual sync vs background scheduling

Manual sync first:

- User taps sync for one confirmed comic or one provider account.
- Koma shows pending/running/succeeded/failed with redacted provider error category.
- No background job, silent auth refresh or periodic upload is allowed in the first implementation.

Background sync requires a later design gate:

- OS scheduling capability review for HarmonyOS.
- Battery/network policy, Wi-Fi only option and metered network behavior.
- Explicit account-level opt-in.
- Token refresh safety, backoff, provider rate limit handling.
- Privacy copy explaining which fields leave the device.

## Honest UX States

Until implementation gates pass, UI must use only non-deceptive states:

| State | User-facing meaning | Implementation notes |
| --- | --- | --- |
| Not connected | No tracker account is connected | Default state for every provider |
| Planned | Provider support is on the roadmap/design only | May link to future settings section, no login action |
| Requires login | Feature cannot run until user connects provider | Only after real OAuth implementation exists |
| Sync disabled | Account may exist but sync toggle is off | Do not schedule jobs or writes |
| Last sync unknown | No successful sync timestamp exists | Do not show fake “just now” or seeded timestamps |
| Mapping required | Comic is not linked to provider entry | No upload until user confirms |
| Verification required | Provider capability has not passed current API/security gate | Used for providers with uncertain OAuth/write support |

Forbidden UX:

- Fake connected accounts.
- “Syncing” animations without a real request.
- Login buttons before OAuth/security storage is implemented.
- Provider badges that imply active integration for local comics.
- Last sync timestamps derived from install time, local progress time or mock data.

## Security and Privacy Risks

| Risk | Impact | Required mitigation before implementation |
| --- | --- | --- |
| Token stored in plain preferences/RDB | Account takeover if device backup/log/artifact leaks | Use secure storage; threat model reviewed |
| OAuth authorization code leaked through logs/deep links | Token exchange by attacker | Redact logs; one-time code handling; PKCE |
| Client secret embedded in app | Secret extraction from APK/HAP | Public client + PKCE or backend proxy |
| Uploading local/private source identifiers | Reveals private library structure | Mapping overlay must strip paths/URLs |
| Incorrect title match | Writes progress to wrong provider entry | User confirmation before first write |
| Background sync surprises user | Privacy and battery trust issue | Manual first; background opt-in later |
| Provider API outage/429 | Data loss or noisy retries | Backoff; no destructive retries; visible failed state |
| Account disconnect incomplete | Token remains usable | Secure token deletion and queue purge test |
| Broad OAuth scopes | Over-collection | Minimum scopes per provider and consent copy |
| Raw provider response in crash/artifact | PII or token leakage | Redacted error model and artifact lint |

## Verification Gates Before Any Implementation

Required before code changes for OAuth/tracker sync:

1. Provider documentation refresh dated in the implementation PR.
2. OAuth flow decision per provider: authorization code + PKCE, unsupported, or backend proxy; password grant is disallowed.
3. HarmonyOS secure storage proof of concept with token write/read/delete and backup/logging behavior reviewed.
4. Redirect/deep-link proof of concept with no token/code leakage in logs.
5. Scope matrix and consent copy reviewed.
6. Provider sandbox/test account plan that does not use real user credentials in artifacts.
7. Static model review proving no token/password/client secret fields are added outside secure storage wrapper.
8. Redaction tests for auth errors, sync logs and artifacts.
9. Mapping confirmation UX design reviewed with wrong-match recovery.
10. Sync dry-run tests with recorded redacted fixtures for success, conflict, 401, 403, 404, 429 and 5xx.

Implementation remains blocked until these gates are complete.

## References Checked

- AniList APIv2 Docs, GraphQL API overview and OAuth docs, checked 2026-05-26: `https://anilist.gitbook.io/anilist-apiv2-docs`
- MyAnimeList API v2 docs and app config pages, checked 2026-05-26: `https://myanimelist.net/apiconfig/references/api/v2`
- Kitsu JSON:API docs, OAuth2/token endpoint and manga/library resources, checked 2026-05-26: `https://hummingbird-me.github.io/api-docs/`
- Bangumi API repo/OpenAPI docs and User-Agent guidance, checked 2026-05-26: `https://github.com/bangumi/api`
- MangaUpdates API availability requires follow-up verification before implementation; no Koma implementation should rely on unaudited third-party wrappers.
