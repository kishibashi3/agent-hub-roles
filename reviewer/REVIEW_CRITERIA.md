# REVIEW_CRITERIA.md — agent-hub ecosystem 統合 review 基準

> `@reviewer` が agent-hub ecosystem 全体 (server + bridges + clients + plugin) を review するときの **judgment axis 正本**。
> 個別レビューでは [`CLAUDE.md`](./CLAUDE.md) の観点優先順 (Security > Correctness > Perf > Readability > Test > Consistency) を **項目** として使い、本ファイルの **判定基準** で具体性を補う。
> ecosystem 固有の redline / pattern / 反例集を一箇所に集約し、新規 reviewer / 自己進化で迷ったら本ファイルに戻る。

最終更新: 2026-05-21 (M5 workdir 整合 + SSE replay / per-user dedup パターン追加)

---

## 0. 全体観: ecosystem の設計上の優先度

review judgment の **北極星** となる思想軸。**「ここを潰すと ecosystem の存在意義が消える」** という順で並べる。

| # | 思想軸 | 出典 | reviewer としての意味 |
|---|---|---|---|
| 1 | **共在 (co-presence)** | `docs/collaboration-model.md`, `docs/messaging-vs-rpc.md:13-19` | 人と AI が **同じ primitive** で発話する世界観を壊す変更は重大。tool 名 / signature の非対称化、人間 only / AI only の API 追加は要警戒 |
| 2 | **HITL の溶解** | `docs/collaboration-model.md:18` | 「人間に聞く」「AI に聞く」が **同じ呼び出し** で行ける状態の維持。`send_message` を peer 型で分岐する設計は anti-pattern |
| 3 | **MCP native** | `README.md:74-82` | MCP SDK の機能 (resource subscribe / event store / notification) は **first-class** で使う。raw HTTP 自作 fallback は disagreed |
| 4 | **ambiguity 耐性 / messaging primitive** | `docs/messaging-vs-rpc.md:32-43` | 厳格な RPC contract より「曖昧を呼吸する会話」を優先。schema validation は **入口** だけで十分、内部で過度に型を絞らない |
| 5 | **民主性 / 参入障壁の低さ** | `docs/messaging-vs-rpc.md:35-43` | 新規 peer 実装の手間が増える変更は要正当化。`mode` 宣言 1 つで参加できる現状を維持 |
| 6 | **C 類型 (共在型) positioning** | `docs/landscape.md:9-16` | 委任型 (A) や orchestration 型 (B) に滑る変更は方向違い。「人が監督、AI がワーカー」の構造を持ち込まない |
| 7 | **OSS / lock-in 回避** | `docs/landscape.md:43` | Anthropic / Google / Microsoft 専用機能に依存しない。各 bridge は SDK 切替可能な構造を保つ |

---

## 観点優先順位 まとめ

| 段 | 意味 | 結論ラベル目安 | 件数で言えば... |
|---|---|---|---|
| 🔴 **Critical** | redline 違反、merge 阻止 | Request Changes | 1 件でも検出したら blocker |
| 🟠 **High** | 設計判断ミス、merge 前に明示緩和が必要 | Request Changes or "LGTM with mitigation plan" | 緩和なしでは進めない |
| 🟡 **Medium** | 改善推奨、author 判断で採否 | LGTM (with Minor) | follow-up issue 化推奨 |
| 🔵 **Low** | 議論余地・好み | LGTM | Suggestion 段で言及 |

---

# 🔴 Critical 観点 (= 即 Request Changes)

これらは **検出したら merge を止める**。author / operator に説明責任あり。

## C1. tenant 境界 leak (= ecosystem の最大 redline)
<a id="C1"></a>

**判定基準**: `tenant_id` が WHERE 句から欠落、または resource URI で tenant 識別ができていない状態。

- **必須 enforce ポイント**:
  - 全 DB query が `WHERE tenant_id = ?` を含む (`src/db/messages.ts:26,37,48,62`, `src/db/participants.ts:21-38`)
  - `TenantScope` (`src/db/tenant-scope.ts:59-102`) を **bypass する直接 db 呼び出し** が tool handler / server.ts に無い
  - SSE / notification dispatch も tenant filter 通過 (`src/mcp/server.ts:406-423` の `selectNotificationTargets`、line 418 `if (session.tenantDomain !== tenantDomain) continue;`)
- **canonical regression test**: `src/mcp/__tests__/notify_dispatch.test.ts:37-56` "別 tenant の同名 handle session には届かない"
- **反例**: issue #7 (commit `d6942f0`) — inbox URI が tenant prefix を持たないため、URI 単独で dispatch 判定すると同名 handle へ cross-tenant leak。**resource URI に tenant が含まれない限り、dispatch 層で必ず 2 軸 filter する**。
- **reviewer の動作**:
  - 新規 tool が DB を直接触っていないか grep
  - 新規 resource URI に tenant 識別子が無い場合、dispatch / read 時の filter ガードを確認
  - 「同名 handle が複数 tenant に居る」シナリオを test に含めているか確認

## C2. 認証 bypass / tenant squat
<a id="C2"></a>

**判定基準**: tenant 所有権、@admin gate、TOFU claim ロジックの semantic 変更。

- **redline**:
  - `AUTH_MODE=trust` は **localhost only** が前提 (`src/mcp/server.ts:86-96`)。production exposure に影響する変更は requires 明示審査
  - named tenant の TOFU claim (`src/mcp/server.ts:199-209`) は **初回 access で owner=githubLogin に固定**。2 回目以降に owner check を緩める変更は squat 復活
  - default tenant の `AGENT_HUB_DISABLE_DEFAULT_TENANT` (`src/mcp/server.ts:179-195`) は **secure-by-default** (= `!== "0"`)。意味反転を再度起こさない
  - deployment 初期化 gate (`src/mcp/server.ts:165-172`, `:219-234`) — `@admin` 未 claim 中の named tenant 503 化は **squat 防止の核**
- **反例**: commit `1394c38` — semantic 反転 (`"1" → !== "0"`) は production audit 必要。env var の意味を逆転させる変更は **migration / breaking change notice 必須**
- **reviewer の動作**:
  - `process.env` の真偽判定が変わる diff は対象 prod deploy の current 値を確認するよう author に求める
  - `claimTenantIfMissing` / `claimOwnerIfUnowned` の呼び出し条件を読み直す

## C3. secrets 露出
<a id="C3"></a>

**判定基準**: PAT / API key / session token がログ / error message / 平文ファイル / git diff に乗っていないか。

- **既存の良い pattern**:
  - bridge-claude: PAT を temp file (`mode 0o600`) に書いて context manager で unlink (`worker.py:49-78`)
  - 全 bridge: PAT は in-memory headers のみ、CLI 引数では渡さない
  - error message は agent-hub からの text を passthrough、独自 dump なし
- **redline**:
  - `console.log` / `logger.info` の引数に PAT / `Authorization` header / session id を入れない
  - error response body に env var を含めない
  - test fixture に **実 PAT** を hardcode しない (= `ghp_test_xxx` 等の dummy 文字列)
- **反例**: 現状 ecosystem 内で実害事例なし。先手で守る redline。

## C4. SQL injection / 動的 SQL
<a id="C4"></a>

**判定基準**: prepared statement を必ず使う。文字列結合で SQL を組み立てる diff は即 Request Changes。

- **既存 pattern**: `db.prepare(...).run(...)` / `.get(...)` / `.all(...)` 一貫 (`src/db/teams.ts:24,44,47` 等)
- **反例**: 現状なし。**新規 admin / ops tool で「動的 column 指定」を求めたくなったら別 design** (= 列挙された白リストから選ぶ等)
- **reviewer の動作**: `${` / `'+' + ` を含む `db.prepare(` 引数を grep で確認

---

# 🟠 High 観点 (= merge 前に明示の緩和策が必要)

## H1. SDK option inversion / framework feature 未活用
<a id="H1"></a>

**判定基準**: MCP SDK / Claude SDK / Slack Bolt 等の重要 option を渡し忘れ、または default の脆弱性を放置。

- **再発防止すべき例**:
  - SSE resumability: `StreamableHTTPServerTransport` に `eventStore` 渡し忘れ (commit `a9dc696` 修正済)。**渡さないと「切断中の push は完全消失、再接続しても無音」**
  - notification: SSE 用 store は `BoundedInMemoryEventStore` (`src/mcp/event-store.ts`) で 200 件 / 10 分 bound (= 仕様、根拠は session recovery window)
  - **[追加 2026-05-21] SSE replay フィルタ**: `notifications/resources/updated` 等の「新着 hint」は再接続 replay 対象から除外すべき (= issue #117 / PR #118 fix)。hint は coalescing 信号であり replay しても double dispatch になるだけ。`BoundedInMemoryEventStoreOptions.replayFilter` で除外可 (= event は store し ID 連続性を保ちつつ replay skip)。
  - **[追加 2026-05-21] rollback env var の命名則**: 新 feature の rollback flag は `MCP_<FEATURE>_DISABLED` の形で **新 feature 名** を DISABLED する名前にする。`FEATURE_DISABLED` = 旧動作に戻る。旧動作の名前を DISABLED にしない (= PR #118 review Critical #1 参照)。
- **reviewer の動作**:
  - SDK transport / client init を含む diff があれば、SDK ドキュメントの "resumability" / "stateful" 章の option を 1 つずつ check
  - 「渡さない場合の default 挙動」を author に説明させる

## H2. transport state と peer state の混同 (= bridge 系)
<a id="H2"></a>

**判定基準**: hub 再接続のたびに peer state (会話履歴・dedup 状態・session id map) がリセットされる構造。

- **既存の正しい pattern**:
  - bridge-claude (monorepo): `ClaudeSDKClient` を **再接続 loop の外** で 1 個保持 (`agent-hub-bridges/src/agent_hub_bridges/claude/worker.py`)。`HUB_RECONNECT_BACKOFF_S=5.0` で外側 retry、内側で SDK 状態維持
  - bridge-gemini (monorepo): `user_sessions: Dict[str, str]` で per-peer Gemini session を cache (`agent-hub-bridges/src/agent_hub_bridges/gemini/worker.py`)
- **反例 (= 修正済)**: bridge-claude commit `92debc1` — hub reconnect loop 内で SDK client を再生成、session 全消失
- **reviewer の動作**:
  - bridge 系 PR では「hub 切断 → 再接続」のとき何が残り、何が消えるかを ASCII 図 1 枚で author に書かせる
  - retry loop の **外** で初期化されるべき state (LLM client、per-peer session map、dedup set) を確認

## H3. semantic inversion of env vars / config
<a id="H3"></a>

**判定基準**: 既存 env var の真偽判定が逆転、または default 値が変わる。

- **過去事例**: `AGENT_HUB_DISABLE_DEFAULT_TENANT` (commit `1394c38`、opt-in → secure-by-default)
- **redline**:
  - 既存 production deploy の current value を audit
  - PR body に「migration path」「現行 prod env の確認結果」を明記
  - 移行猶予なしの flip は禁止 (= 警告期間 or env var 名そのものを変える)
- **reviewer の動作**: `process.env.` の真偽判定 / default を変える diff は **必ず PR body の migration セクションを要求**

## H4. fallback routing 抜け (= bridge / dispatch 全般)
<a id="H4"></a>

**判定基準**: 「primary 経路で見つからない peer / thread / tenant」のときの挙動が落とし穴になっていないか。

- **過去事例**: bridge-slack commit `9768f8a` — `_resolve_target` が `thread_for_peer` map にない peer を silently drop
- **reviewer の動作**:
  - dispatch logic の `if (lookup) {...}` を見たら **else 側で何が起こるか** を 1 行コメントで author に要求
  - 「empty / default / unbound」path の test が 1 件以上あるか確認

## H5. error の swallow / 黙殺
<a id="H5"></a>

**判定基準**: `except BaseException` で **log のみ**、retry / surface なしの coding。

- **既存の良い pattern**:
  - bridge-slack: `PeerNotFoundError` / `HubTransientError` (`hub.py:35-55`) で **分類**、`classify_hub_error` (`routing.py:287-337`) で pattern match
  - `send_message_with_retry` (`hub.py:258-306`): max 3 attempts、exp backoff
- **反例**:
  - bridge-adk `worker.py:114,139,151`: 全部 `except Exception` で log + continue。**alpha では許容、production 移行時に分類必須**
  - client-litellm: registration が best-effort silent fail (`main.py:75-87`)。**stateless なら許容、stateful 化したら redline**
- **reviewer の動作**:
  - bridge / client の新規 except block で「分類 / retry / surface のどれか」を明示要求
  - silent swallow は test 上は通るので **CR で必ず指摘**

## H6. notification non-fatal の penetration
<a id="H6"></a>

**判定基準**: notification dispatch の失敗が本体処理 (message persist) を巻き込まない構造。

- **既存 pattern**: `src/mcp/tools/send_message.ts:60-74` — `try/catch` で `console.error` のみ、message は永続化済
- **redline**: 新規 dispatch 経路 (= 別 resource URI / 別 event 型) 追加時も **fire-and-forget** を守る。notification 失敗で tool error にしない
- **reviewer の動作**: 新規 `notification(...)` 呼び出しが try/catch 内にあるか + メイン処理を巻き込まない構造か確認

---

# 🟡 Medium 観点 (= Minor / follow-up issue 化推奨)

## M1. test coverage (特に tenant leak guard と FK 抜け)
<a id="M1"></a>

- **base line**: 全 PR (`#8`, `#9`, `#14`) で `npm test` の通過件数と新規 test 数が PR body に明記。**test 無し PR は merged 実績なし**
- **canonical "tenant leak guard" 形**: `src/mcp/__tests__/notify_dispatch.test.ts:11-56`
  - 同名 handle / 別 tenant 2 session を用意 → 片方への送信が他方に行かないことを `expect(targets).not.toContain('sid-A')` で **absence assertion**
- **要求 baseline**:
  - 新規 tool: success / error / tenant boundary の 3 case 必須
  - schema 変更: 新旧 field の前方 / 後方互換 assertion
  - FK / soft-delete 絡みの変更: deleted_at IS NOT NULL の row が response に混ざらないかの test
- **反例 (= 過去 PR #14 で自分が指摘した)**: `team_members` の FK は participant 側に CASCADE が無く、soft-deleted participant が `team.members` に phantom 残留 (`src/db/teams.ts:203-217`, `src/db/schema.sql:65-66`)。**FK ありでも soft-delete pattern を併用する場合は JOIN filter 必須**

## M2. discriminated union narrowing
<a id="M2"></a>

- **既存の良い例**: `src/mcp/tools/get_participants.ts:48-62` の `ParticipantEntry` — `type: 'person' | 'team'` で union、`as const` で literal 化
- **要求**: 戻り値で「entry に種類がある」なら **union + discriminator field** を必ず置く。flat array に optional field を混ぜる anti-pattern を避ける
- **reviewer の動作**: 新規 response 型に optional field が多い場合、union 化を提案

## M3. error handling pattern (server 側)
<a id="M3"></a>

- **既存 pattern**: tool handler は `try / catch` で `{ content: [{type:'text', text:JSON.stringify(...)}], isError: true }` を返す (`src/mcp/tools/send_message.ts:94-114`)
- **helper**: `errorResult()` / `ok()` (`src/mcp/tools/admin.ts:38-49`)
- **不一致 (= 改善余地)**: schema validation を try の **外** でやる handler と **内** でやる handler が混在。**reviewer は新規 handler で「validation は try 外、business は try 内」の分離を suggest**

## M4. heartbeat / recovery cadence
<a id="M4"></a>

- **bridge-claude baseline** (monorepo): `HEARTBEAT_INTERVAL_S=60.0`, `HUB_RECONNECT_BACKOFF_S=5.0` (`agent-hub-bridges/src/agent_hub_bridges/claude/config.py` or `worker.py`)
- **bridge-slack workaround** (monorepo): 600s 再 subscribe (`agent-hub-bridges/src/agent_hub_bridges/slack/worker.py`) — MCP subscribe の効果が時間で薄れる issue の暫定対応
- **要求**: 新規 bridge / client は heartbeat or 再 subscribe を **必須** (= 「無いと stuck inbox で気づけない」)。間隔は doc に書く

## M5. retry strategy 一貫性
<a id="M5"></a>

- **既存の良い例**: bridge-slack `send_message_with_retry` (`hub.py:258-306`) — max 3, exp backoff (1s/2s/4s)、`PeerNotFoundError` は即 raise
- **要求**: 新規 retry 実装は **(a) 最大回数, (b) backoff, (c) 即諦め条件** の 3 つを doc + code 両方に書く
- Slack rate-limit: `parse_slack_retry_after` (`routing.py:340-368`) を mimic、malformed `Retry-After` の fallback (= 1s) を持つ

## M6. N+1 / perf judgment
<a id="M6"></a>

- **alpha tolerance**: 規模見積もり (= 「数十件 / tenant 想定」) を comment で明示すれば許容。例: `src/mcp/tools/get_participants.ts:92-94`
- **要求**: N+1 を採用する PR は **JOIN 化の trigger** (= 「100 件超 / p95 latency 観測時」) を follow-up issue として残す
- **反例**: alpha 言い訳で **trigger 無し** の N+1 → reviewer は trigger を要求

---

# 🔵 Low 観点 (= Suggestion / 議論余地)

## L1. type safety / `any` の抑制
<a id="L1"></a>

- **既存 pattern**: tool handler args は `unknown`、zod parse で narrow (`src/mcp/tools/send_message.ts:47`)
- **要求**: 新規 code で `any` 出現は理由を comment、無理なら `unknown` + 型ガード
- **既存の弱点**: `as Participant` 等の type assertion が散見 (`src/db/participants.ts:29`)。**reviewer は型ガード / zod 化を Suggestion 段で言及**

## L2. docstring + comment の "why"
<a id="L2"></a>

- agent-hub の existing comment は **why ベースで非常に充実** (例: `src/mcp/server.ts:106-138` の policy 図解)
- **要求**: 新規追加コードに「なぜそう実装したか」が無い diff は Suggestion で why コメント追加を提案

## L3. tool description の token budget
<a id="L3"></a>

- LLM が tool 選択時に読む。person/team の全 field 列挙は正確だが冗長 (例: `src/mcp/tools/get_participants.ts:21-25`)
- **Suggestion**: 詳細は response / 別 resource に逃がし、description は短く

## L4. design doc lag
<a id="L4"></a>

- **既知の弱点**: `docs/landscape.md`, `docs/collaboration-model.md` は `🚧 スケルトン` のまま。SSE bound (200 件 / 10 分) / heartbeat 間隔 / reconnect backoff は code comment / commit message に閉じている
- **Suggestion**: 非自明な algorithmic 定数を入れる PR は対応する design doc セクションを更新するよう促す

## L5. PR body 構成 (既に高水準だが)
<a id="L5"></a>

- 推奨 template: Summary / 修正前の挙動 / 修正アプローチ / 受け入れ条件 (checkbox) / Test plan (typecheck + test 件数)
- 例: PR `#8`, `#9`, `#14` 全て準拠

---

# Research Report 観点 (R1-R8)

> `@reviewer` が **research report PR** (= @researcher / @deep-research が起票する調査成果 PR) を review するときの専用 rubric。
> code PR 用の C1-C4 / H1-H6 / M1-M6 とは独立した評価軸。

[追加 2026-05-22: @deep-research deep-research による Mythos Outcomes 知見の適用]

## R1. 1 次資料の引用
<a id="R1"></a>

**PASS**: 断定的な事実記述に必ず file:line / commit hash / issue番号 / URL が付いている  
**Request Changes**: 「〜らしい」「〜と思われる」等の不確かな記述が根拠なく断定体で書かれている  
**N/A**: 全て推測・未確認として明示されている場合

## R2. 断定 / 推測 / 未確認の区別
<a id="R2"></a>

**PASS**: 事実断定 / 推測 / 未確認の 3 種が文体または明示ラベルで区別されている  
**Request Changes**: 推測が断定と同一文体で混在し、読者が信頼度を判断できない  
**reviewer の動作**: "〜はずだ" / "〜だろう" が出典なしで並ぶ場合は R2 違反

## R3. 影響範囲の明示
<a id="R3"></a>

**PASS**: 調査結論に関連する file / 機能 / 外部依存が Grep/Glob 結果または具体的な参照で確認されている  
**Request Changes**: 影響範囲が「〜に影響する可能性がある」止まりで、実際の grep 結果や参照がない  
**reviewer の動作**: "影響範囲" 節が「可能性」のみなら確認を要求

## R4. 比較表の完全性 (複数案がある場合)
<a id="R4"></a>

**PASS**: 複数案を比較する場合、案 / 長所 / 短所 / 影響範囲の最低 3 列が揃っている  
**Request Changes (Minor)**: 選択肢を列挙しているが比較軸がなく、読者が判断できない  
**N/A**: 単一案のみの調査の場合

## R5. Convergent framing (self-congratulatory framing の回避)
<a id="R5"></a>

**PASS**: 他 system / framework を "後追い" / "我々が上位" / "validate された" 等で評価していない。「異なる starting point からの収束」「multi-dimensional taxonomy」で記述されている  
**Request Changes (Minor)**: self-congratulatory wording が含まれる (例: "Anthropic は我々の設計を後追いした")  
**出典**: researcher/CLAUDE.md § Convergent framing principle

## R6. 推奨の根拠 + 反対意見
<a id="R6"></a>

**PASS**: 推奨がある場合、根拠 (1 次資料ベース) と反対意見・リスクがセットで記載されている  
**Request Changes**: 推奨に根拠のみ / 反論なし、または「現時点での推奨」という限定なしに断定されている  
**N/A**: 推奨 section なし (事実整理のみの調査は推奨不要)

## R7. 未調査の明示
<a id="R7"></a>

**PASS**: 「未調査 / Follow-up 候補」節に未確認事項が明示的に列挙されている  
**Request Changes (Minor)**: 調査の空白が report 内で触れられず、読者が completeness を判断できない  
**reviewer の動作**: 空の "未調査" 節は OK (= 全て確認済みと断言できるなら)。節自体がない場合は Minor で要求

## R8. Deliverable form の適切さ
<a id="R8"></a>

**PASS**: 依頼 form (DM-primary / issue comment / research-archive PR) と成果物の form が一致している  
**Request Changes (Minor)**: 依頼が「DM で報告」なのに PR のみで報告、またはその逆  
**出典**: researcher/CLAUDE.md § Researcher deliverable patterns

---

## Research Report の LGTM 判定基準

| 軸 | 判定 |
|---|---|
| R1-R3 のいずれかが **Request Changes** | 全体 Request Changes |
| R4-R8 のいずれかが **Request Changes (Minor)** | LGTM (with Minor) — follow-up issue 化推奨 |
| R1-R8 全て PASS または N/A | LGTM ✅ |

R5 (Convergent framing) は Minor 扱い (code PR の Critical 相当ではない)。

---

# collaboration model 観点 (= 将来の enforce 候補)

`docs/collaboration-model.md` は現在 `🚧 スケルトン` (3 つの TODO: 境界条件、署名表現、委任 scope 記述形式)。**今後 code に落ちる際の review 視点を先取り**:

## 発話レベル L0 / L1 / L2

- **L0 (自動応答可)**: 事実応答 / 未読確認 / 定型挨拶。
  - reviewer 視点: L0 認定する tool は **副作用 ≤ read-only** が暗黙の要件
- **L1 (確認必須)**: 意思決定を伴う発話。
  - reviewer 視点: L1 tool は **idempotent or rollback 可能** であるべき
- **L2 (人間専有)**: 契約 / 対外コミットメント。
  - reviewer 視点: L2 enforcement の bypass がコードに無いか確認

## 署名規約 (`@bob (proxy of @kishibashi)`)

- DB 側に「代理 sender」「principal」を分けて持つ schema 拡張が必要になる時、reviewer は **audit trail (= 誰が誰の代わりに発話したか) の永続性** を要求

## 委任 scope (policy)

- 発話 policy が YAML / DSL / 自然言語のいずれで表現されても、reviewer は **(a) 失効条件, (b) 取り消し方法, (c) policy 違反時の挙動** の 3 点を要求

## team metadata との接続

- PR #14 で `team.owner / members / created_at` が露出した。**team owner が L1 / L2 enforcement の identity source** になる。
- reviewer 視点: team owner 変更 / member 追加削除の tool が出てきたら `softDelete` との整合 (M1 既知 phantom 問題) を必ず check

---

# breaking change 評価 framework

PR で response shape / API contract / env semantics が変わるとき、reviewer は以下を順に確認:

## ステップ 1: 影響範囲を grep で確定

ecosystem 内の consumer を全 grep:
```bash
grep -r "<changed_symbol>" private/agent-hub-bridges private/agent-hub-plugin-vscode private/kishibashi3-plugins-claude
# ※ M5 完了 (2026-05-21): standalone agent-hub-bridge-claude / -slack / -gemini は archive 済 → agent-hub-bridges monorepo に統合
```

各 hit を **(a) actual code consumer / (b) doc 言及のみ / (c) error message 文字列** に分類。

## ステップ 2: 各カテゴリの追従要否

| カテゴリ | 必要なアクション |
|---|---|
| (a) code consumer | 同じ PR 内 or 同期して別 PR、merge 順序を author に決めさせる |
| (b) doc 言及 | 別 PR で OK、ただし PR body で「**doc は別 PR**」を明示 |
| (c) error message 文字列 | 多くは無害、ただし human-readable な text が古いままだと debug 阻害 |

## ステップ 3: PR body の `Breaking change` セクション必須化

- 旧 shape / 新 shape の diff (例: `flat array → discriminated union`)
- migration 例 (`filter(e => e.type === 'person')` 等)
- 「**code レベルで追従が必要な箇所はゼロ**」を結論として書いた reviewer 自身の grep 結果を message に残す (例: 2026-05-16 PR #14 レビュー参照)

## ステップ 4: rollout strategy

- 「警告期間あり / なし」「prod deploy の current 状態確認」(= H3 と同じ精神)

---

# 過去の bug 反例集 (= "ここを reviewer が見落としそう" の標本)

| commit / PR | 何が漏れたか | reviewer が次回 catch すべき pattern |
|---|---|---|
| **d6942f0 / #8** | SSE inbox URI に tenant が含まれず、URI 単独 dispatch で cross-tenant leak | resource URI に tenant が含まれないなら、dispatch 層で `(uri, tenantDomain)` 2 軸 filter を必須化 |
| **a9dc696** | `StreamableHTTPServerTransport` に `eventStore` 渡し忘れ → SSE resumability 全消失 | SDK transport init の diff は全 option を 1 つずつ docs と照合 |
| **1394c38** | `AGENT_HUB_DISABLE_DEFAULT_TENANT` の意味反転 (`"1" → !== "0"`) | env 真偽判定 / default の変更は production audit + migration セクション要求 |
| **834e81f** | schema に `display_name` 定義済だが SELECT 句から欠落 | interface 定義と query column を 1 行ずつ照合 |
| **e4c0e28** | re-register で `mode` 更新するが `display_name` 無視 | create / update 分岐の field 対称性を確認 |
| **92debc1** (bridge-claude → agent-hub-bridges に統合) | hub reconnect loop 内で SDK client 再生成、session 全消失 | retry loop の **外** で初期化すべき state を明示 |
| **9768f8a** (bridge-slack → agent-hub-bridges に統合) | `_resolve_target` が unmapped peer を silent drop | fallback / else path の挙動を必ず確認 |
| **PR #14 leftover** | `team_members` FK に participant 側 CASCADE 無、soft-deleted member が phantom 残留 | FK + soft-delete 併用 schema は JOIN filter を必ず check |
| **issue #114 / server PR** (2026-05-21) | zombie session 31 件蓄積で同一 user に 31x push fanout (= `notifyResourceUpdated` が全 sessions に dispatch) | `selectNotificationTargets` で per-user dedup (= `lastActiveLookup + createdAt tie-breaker`) を確認。同 (tenant, userId, uri) 複数 subscriber は 1 session 選択が invariant |
| **issue #117 / PR #118** (2026-05-21) | SSE 再接続 replay で `notifications/resources/updated` が再送 → double dispatch | hint 系通知 (`notifications/resources/updated`) は replay 対象から除外。`replayFilter` option の有無と rollback env var 命名 (`MCP_<FEATURE>_DISABLED` 規則) を確認 |
| **SDK issue #31** (2026-05-21) | SSE replay 経由で inbox push が double dispatch → SDK v0.7.0 で inbox message ID dedup | SDK 側の last-resort defence だが、server 側 replay filter (PR #118) との defence-in-depth として両方揃っているか確認 |

---

# レビュー時の確認手順 checklist (= 上記の運用形)

新規 PR を受けたら、persona doc の必須手順に加えて以下を **頭で walk-through**:

1. **🔴 Critical 4 項目 (C1-C4) の redline 違反が無いか**
   - tenant_id 抜けの DB query
   - auth bypass / TOFU 緩和
   - secrets 露出
   - 動的 SQL
2. **🟠 High 6 項目 (H1-H6) の trade-off が PR body に書かれているか**
3. **breaking change の場合は framework ステップ 1-4 を実行**
4. **過去の反例 (= 上記表) と diff を照らし合わせ、同類パターンが無いか**
5. **🟡 Medium / 🔵 Low は report に Minor / Suggestion として記載**
6. **collaboration model 関連 (delegation / 署名 / L0-L2) に触れる PR は将来 enforce 観点を Suggestion で添える**

---

# 自己進化メモ (= reviewer が育つ場所)

新規 ecosystem 変更や bridge 追加が起きたとき、本ファイルに **追記 / 改版** する。改版時:
- `[追加] YYYY-MM-DD: <観点名>` を当該段の末尾に記す (= audit trail)
- 既存基準と矛盾する場合は **古い基準を strikethrough (~~~ ~~~) で残す** (削除しない、判断の歴史も価値)
- 大改版は `feedback-archive/YYYY-MM-DD-criteria-revision-<topic>.md` に rationale を残す

## 関連 docs

- 振る舞いの正本: [`CLAUDE.md`](./CLAUDE.md)
- 出力 format の正本: [`REVIEW_TEMPLATE.md`](./REVIEW_TEMPLATE.md)
- 過去 review: [`feedback-archive/`](./feedback-archive/)
- 設計思想: `~/app/private/agent-hub/docs/collaboration-model.md`, `landscape.md`, `messaging-vs-rpc.md`
