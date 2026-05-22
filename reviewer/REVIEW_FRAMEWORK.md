# REVIEW_FRAMEWORK.md — Review 観点 選択フレームワーク

> `@reviewer` が **任意の PR / project に対し、どの観点を適用するか** を決めるための **箱の構造** と **選択フロー**。
> 中身 (= 各観点の具体 redline / pattern / 反例) は本 framework に格納されていくが、初版は **箱 + 選択ロジック** のみ用意する。
> project 固有の判定基準 (= 現行 `REVIEW_CRITERIA.md` の agent-hub ecosystem redline 集) は `§1 C` に index で組み込まれ、物理ファイルは別途参照する。

最終更新: 2026-05-17 (初版、空箱 + 選択フロー)
issue: [kishibashi3/agent-hub-reviewer#1](https://github.com/kishibashi3/agent-hub-reviewer/issues/1)

---

## 0. なぜ framework が必要か

reviewer は agent-hub ecosystem 専属ではない (= `~/app/ntv/backend`, `~/app/ntv/agents` 等の業務 project、将来は外部 project の review も視野)。
PR ごとに適用観点が異なるため、**「全観点 × 全 PR」をなぞる方式は破綻** する。**「この PR にどの観点が当たるか」を先に決める仕組み** が要る。

軸を 1 つも引かない reviewer は:
- platform 固有の落とし穴 (= AWS IAM wildcard、Unity の GC alloc) を見落とす
- 言語慣習 (= Go の error wrapping、Python の async leak) を見落とす
- architecture pattern (= microservice 境界跨ぎ、CQRS の write/read model 同期) を見落とす

逆に **全観点を機械的に当てると noise が増え**、author が「本当に重要な指摘」を見失う。**選んで当てる** ことが正解。

---

## 1. 観点の分類体系 (= taxonomy、3 段構造)

**A → B → C** の順で適用範囲が狭くなる。

```
A. Universal       (= 全 PR で必ず適用、選択不要)
B. Context         (= PR の属性で軸を引いて適用、軸ごとに 0..N 件)
C. Ecosystem       (= 特定 project 固有、既存 REVIEW_CRITERIA.md 系)
```

### A. Universal 観点 (= 常時適用、選択フロー対象外)

全 PR で必ず check。中身は段階的に埋める (`§5` roadmap 参照)。

| code | 観点 | 中身の placeholder (= 後で埋める) |
|------|------|---|
| A1   | Security 基本 | secrets 漏洩 / injection / auth bypass / 認可漏れ (= 普遍部分のみ、cloud 固有は B1) |
| A2   | Correctness | logic / edge case / null 安全 / error 処理 / race condition |
| A3   | Readability | 命名 / 関数の責務 / 抽象度 / why コメント |
| A4   | Test coverage | 変更に test が付くか、edge case 網羅、test の独立性 |
| A5   | Breaking change 評価 | API contract / response shape / env semantics の変更、grep + migration の framework (= 現行 `REVIEW_CRITERIA.md §breaking change` から将来移管) |

### B. Context-dependent 観点 (= 軸を引いて適用、各軸 0..N 件)

PR の属性から **0 件 ~ 複数件** を選んで適用。中身は遭遇時に埋める。

#### B1. Platform 軸

| code | platform | 中身の例 (= placeholder) |
|------|----------|---|
| B1.AWS | AWS | IAM wildcard / VPC egress / S3 public bucket / KMS key rotation |
| B1.GCP | GCP | IAM role granularity / VPC SC / Cloud Run min-instances / Workload Identity |
| B1.Azure | Azure | RBAC / NSG / Managed Identity / Key Vault access policy |
| B1.Mobile.iOS | iOS | App Transport Security / Keychain / background mode / privacy manifest |
| B1.Mobile.Android | Android | permission scope / ProGuard / Notification channel / WorkManager |
| B1.Unity | Unity | GC alloc in Update / coroutine leak / Addressables / build size |
| B1.Edge | Edge / IoT | OTA 失敗時 rollback / 帯域制約 / 証明書失効 |
| B1.OnPrem | On-prem / bare-metal | systemd / cron / log rotation / firewall |

#### B2. Language 軸

| code | language | 中身の例 |
|------|----------|---|
| B2.Go | Go | error wrapping (`%w`) / goroutine leak / context cancellation / defer の順序 |
| B2.Python | Python | async leak / GIL 仮定 / pickle untrusted / mutable default args |
| B2.TS | TypeScript | `any` 抑制 / strict null check / discriminated union narrowing |
| B2.JS | JavaScript | prototype pollution / loose equality / event listener leak |
| B2.Java | Java | NPE / equals/hashCode / mutable static / classpath conflict |
| B2.Kotlin | Kotlin | nullable platform type / coroutine scope / data class semantics |
| B2.Rust | Rust | unwrap / unsafe / Send+Sync 違反 / lifetime |
| B2.C | C / C++ | memory leak / UB / lifetime / signed overflow |

#### B3. Architecture 軸

| code | architecture | 中身の例 |
|------|--------------|---|
| B3.Mono | Monolith | 結合度 / circular import / fat module |
| B3.ModMono | Modular / shared monolith | module 境界違反 / shared db rule / 公開 API の偶発露出 |
| B3.Micro | Microservice | service 境界跨ぎ / chatty API / saga 失敗時 rollback / version skew |
| B3.Serverless | Serverless / FaaS | cold start / 関数の純度 / timeout / idempotent / VPC ENI 枯渇 |
| B3.Batch | Batch / pipeline | retry / partial failure / watermark / 中断時 resume |
| B3.EdgeDist | Edge-distributed | 結果整合性 / clock skew / オフライン耐性 |

#### B4. Layering / 設計 pattern 軸

| code | layering | 中身の例 |
|------|----------|---|
| B4.Clean | Clean Architecture | dependency 方向 / use case の責務 / interface 抽出位置 |
| B4.Hex | Hexagonal / Ports-Adapters | port / adapter の混在 / domain への inbound 漏れ |
| B4.MVC | MVC / MVP | controller の太り / fat model / view の業務化 |
| B4.MVVM | MVVM | binding leak / view が業務を持つ / state ownership |
| B4.Onion | Onion | infrastructure → domain leak |
| B4.VS | Vertical Slice | feature 内重複と共通化境界 |

#### B5. Paradigm 軸

| code | paradigm | 中身の例 |
|------|----------|---|
| B5.OO | Object-oriented | 継承の深さ / SOLID 違反 / mutable state の伝播 |
| B5.FP | Functional | 副作用の閉じ込め / referential transparency / IO の境界 |
| B5.Proc | Procedural | step 数 / 状態変数の寿命 / 早期 return の方針 |
| B5.Mixed | Mixed paradigm | パラダイム混在の境界 / 一貫性 |

#### B6. Messaging / 通信 軸

| code | pattern | 中身の例 |
|------|---------|---|
| B6.PubSub | Pub-Sub | delivery 保証 / consumer lag / fan-out scaling |
| B6.EventDriven | Event-driven / Event sourcing | event ordering / schema evolution / replay 安全性 |
| B6.CQRS | CQRS | write/read model 同期 / projection lag |
| B6.RW | Read-write 分離 | replica lag / read-your-writes |
| B6.REST | REST | idempotent / status code / versioning / pagination |
| B6.gRPC | gRPC | streaming / deadline propagation / compatible field 削除 |
| B6.MQ | Message queue | at-least-once / poison message / dead-letter |
| B6.WS | WebSocket / SSE | reconnect / resumability / backpressure |

#### B7. Data 軸

| code | data store | 中身の例 |
|------|------------|---|
| B7.RDB | RDB (SQL) | tx 分離 / index / N+1 / migration 可逆性 |
| B7.NoSQL.KV | Key-value | hot key / TTL / eviction policy |
| B7.NoSQL.Doc | Document | schema drift / aggregation 限界 |
| B7.NoSQL.Wide | Wide-column | partition key / hot partition |
| B7.Graph | Graph DB | traversal depth / cycle / index hint |
| B7.TimeSeries | Time-series | downsampling / retention / cardinality |
| B7.Cache | Cache | invalidation / stampede / negative cache |

### C. Ecosystem-specific 観点 (= 特定 project 固有の redline 集)

中身が大きくなるので **各 C.* は別ファイル**、framework は index のみ持つ。

| code | ecosystem | 出典ファイル | 状態 |
|------|-----------|--------------|------|
| C.agent-hub | agent-hub ecosystem (server + bridges + clients + plugin) | [`REVIEW_CRITERIA.md`](./REVIEW_CRITERIA.md) | ✅ 充実 (C1-C4 / H1-H6 / M1-M6 / L1-L5、commit `392b2ed` 時点) |
| C.ntv.backend | NTV backend | (未作成、空箱) | 🔲 後日 |
| C.ntv.agents | NTV agents | (未作成、空箱) | 🔲 後日 |
| C.ntv.agent-probe | NTV agent-probe | (未作成、空箱) | 🔲 後日 |

ecosystem 固有観点は **「対象 project がどれか」** で 1 対 1 で決まる (= 軸選択フロー対象外、`§2.0` で別途決定)。

---

## 2. 観点の選択フロー (= PR 1 件あたりの判定)

新規 PR を受けたら、以下を順に実行する。

### §2.0 ecosystem 判定 (= C 系列の選択)

PR の repo / path から ecosystem を決定。複数 ecosystem を跨ぐ PR は **各々の C.* を union**。

```
repo path contains  "agent-hub"        → C.agent-hub
repo path contains  "ntv/backend"      → C.ntv.backend (空箱)
repo path contains  "ntv/agents"       → C.ntv.agents (空箱)
それ以外                                 → C 段なし (= A + B のみ)
```

### §2.1 軸の判定 (= B 系列の選択)

PR の以下の signal を読み、各軸の値を決める。

| 軸 | 判定 source |
|----|-------------|
| B1 Platform | `infra/`, `terraform/`, `.github/workflows/`, `Dockerfile`, `serverless.yml`、`requirements.txt` / `package.json` の cloud SDK |
| B2 Language | 変更ファイルの拡張子分布 (上位 1-2 を採用)、`README` の Stack 記述 |
| B3 Architecture | repo root の `services/` `packages/` `apps/`、`docker-compose.yml`、`serverless.yml`、`Procfile` |
| B4 Layering | `domain/` `usecase/` `adapter/` `internal/` 等の dir 名、README / docs の architecture 章 |
| B5 Paradigm | 主要言語の慣習 + class/function ratio、副作用の閉じ込め有無 |
| B6 Messaging | event/queue/topic キーワード grep、`sqs` `kafka` `pubsub` `redis-streams` 依存、`@Subscribe` / `@MessageHandler` decorator |
| B7 Data | `migrations/`, `schema.sql`、依存に `pymongo` / `redis` / `sqlite` / `pg` / `dynamodb` |

**各軸は 0 件選択も可**。例: ML 学習スクリプト PR → B2.Python + B3.Batch のみ、B6 / B7 は 0 件。
**1 軸で複数選択も可**。例: hybrid 移行 PR → B3.Mono + B3.Micro 両方。

### §2.2 観点の union

```
適用観点 = A (= 全 universal) ∪ §2.1 で選ばれた B.* ∪ §2.0 で選ばれた C.*
```

### §2.3 優先度に並べ替え + 出力

選ばれた観点を、**A / B / C を跨いで** Critical / High / Medium / Low に並べる。最終出力は `REVIEW_TEMPLATE.md` の format に従う。

```
🔴 Critical: 各観点の Critical 段の指摘を全て列挙
🟠 High:     各観点の High 段
🟡 Medium:   各観点の Medium 段
🔵 Low:      各観点の Low 段
```

中身が **空箱の観点** は report の確認範囲表に `⚠️ <code> (= 中身未定義、本 PR では skip)` と記録 → 次回 framework 改版で埋める learning loop の trigger になる。

---

## 3. 優先度 (Critical / High / Medium / Low) の意味

観点の **分類 (A/B/C)** と **優先度 (Critical/High/Medium/Low)** は **直交**。
分類は「**どの PR に当たるか**」、優先度は「**当たったときの重さ**」を決める。

| 段 | 意味 | 結論ラベル目安 |
|----|------|----------------|
| 🔴 Critical | redline 違反、merge 阻止 | Request Changes |
| 🟠 High | 設計判断ミス、緩和必須 | Request Changes or "LGTM with mitigation plan" |
| 🟡 Medium | 改善推奨、author 判断 | LGTM (with Minor) |
| 🔵 Low | 議論余地・好み | LGTM |

(= 既存 [`REVIEW_CRITERIA.md` 観点優先順位まとめ](./REVIEW_CRITERIA.md) と同じ axis、再掲)

---

## 4. 既存 `REVIEW_CRITERIA.md` との関係 (= リファクタ index)

既存 `REVIEW_CRITERIA.md` は **C.agent-hub の中身そのもの** とみなす。物理ファイルは当面 **そのまま** 残し、本 framework は index で参照する。将来分離する場合の対応表:

| 既存セクション | 移行先 (= 概念上) |
|----------------|------------------|
| `§0 全体観: ecosystem の設計上の優先度` (思想軸 7 点) | C.agent-hub.思想軸 |
| `§観点優先順位 まとめ` | A 段 (= universal、本 framework `§3` へ統合) |
| `§Critical C1-C4` | C.agent-hub.Critical |
| `§High H1-H6` | C.agent-hub.High |
| `§Medium M1-M6` | C.agent-hub.Medium |
| `§Low L1-L5` | C.agent-hub.Low |
| `§collaboration model 観点` | C.agent-hub.将来 enforce 候補 |
| `§breaking change 評価 framework` | **A5 (Universal)** へ昇格候補 (= project 不問のため) |
| `§過去の bug 反例集` | C.agent-hub.反例集 |
| `§レビュー時の確認手順 checklist` | 本 framework `§2` で代替 |
| `§自己進化メモ` | 本 framework `§6` と統合 |

**段階的リファクタの方針**:
1. 今回 (= 初版): 本 framework 追加、既存 `REVIEW_CRITERIA.md` は無編集
2. 次回: 既存ファイルの先頭に「本ファイルは C.agent-hub の中身として framework から参照される」旨の 1 行 frontmatter を追加
3. 後日: 必要に応じて物理分割 (= `axes/`, `ecosystems/` ディレクトリ化)

---

## 5. 中身を埋める順序 (= roadmap)

issue 趣旨「中身は空箱でOK、まず構造」を踏まえ、埋める順序:

1. **本 framework (= 本ファイル)** 導入、index 完成 ← **今ここ**
2. **A 段** (Universal) の中身を逐次埋める (= 最汎用、再利用効くため最優先)
   - 特に `A5 Breaking change 評価` は既存 `REVIEW_CRITERIA.md §breaking change` を抜粋して移植
3. **B2** (Language) を埋める (= 当面 review 対象の Python / TS / Go を先に)
4. **B3 / B6** を埋める (= 業務 ntv 系で頻出予測)
5. **B1** (Platform) は遭遇したら追加 (= AWS / GCP のどちらか先になりがち)
6. **B4 / B5 / B7** は遭遇ベース
7. **C.ntv.*** は対応 project の review 着手時に作る

各箱を埋める **trigger**:
- (a) review でその観点が必要になった、かつ中身が空だった
- (b) 過去の反例が蓄積され、抽象化したくなった

埋める **粒度**: 「Critical / High / Medium / Low の placeholder 1 行ずつ」から始めればよい。空のままより、placeholder 1 行ある方が次回 review でヒット率が高い。

---

## 6. 自己進化 (= framework の育て方)

本 framework は **事前計画ではなく、事後の集約場所**。

- 新規 PR で新しい観点に遭遇 → 本 framework の該当箱に **1 行** だけでも追記
- 既存箱の中身が膨らんだ → 別ファイル化を検討 (例: `axes/B2_python.md`)
- 軸そのものの過不足 (= 「B8. UI/UX 軸が要る」「B6 と B7 の境界が曖昧」) は **改版** で対処
- 改版時は冒頭の `最終更新` を更新し、`feedback-archive/YYYY-MM-DD-framework-revision-<topic>.md` に rationale を残す

---

## 関連 docs

- 振る舞いの正本: [`CLAUDE.md`](./CLAUDE.md)
- 出力 format の正本: [`REVIEW_TEMPLATE.md`](./REVIEW_TEMPLATE.md)
- C.agent-hub の中身 (= ecosystem 固有 redline 集): [`REVIEW_CRITERIA.md`](./REVIEW_CRITERIA.md)
- 過去 review: [`feedback-archive/`](./feedback-archive/)
- 関連 issue: [#1 feat: review観点の選択フレームワーク設計](https://github.com/kishibashi3/agent-hub-reviewer/issues/1)
