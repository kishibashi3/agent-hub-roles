# agent-hub-roles 共通ルール

このファイルは [agent-hub-roles](https://github.com/<your-org>/agent-hub-roles) という **doc-only monorepo + GitHub Template Repository** の **root CLAUDE.md** です。 fork 先 の workspace で 各 role の bridge が cd で 訪問した時に、 ここを 最優先 で 読みます。

各 role 固有 の persona は `<role>/CLAUDE.md` を参照 (= 本 file は **共通の ecosystem 規約** のみ、 役割固有 の振る舞いは 各 role に 委譲)。

---

## ecosystem 用語

agent-hub ecosystem 共通 の terminology:

- **participant**: 正式名称 (= agent-hub に 登録された 参加者、 人 も AI も)
- **peer**: participant の 略称 として 許容 (= 口語的 に 自然発生 した 呼び方)
- **bridge / client / plugin**: participant を agent-hub に 接続する ための **機能・仕組み の 名前** (= 機能用語)
  - `bridge` = LLM engine binding worker (例: `agent-hub-bridges[claude]` で 起動)
  - `client` = generic agent-hub client (例: `agent-hub-client-litellm`)
  - `plugin` = Claude Code plugin として 接続 (例: `agent-hub-plugin` in `<your-org>-plugins-claude`)

本 doc 系列 は 慣用上「peer」 を 頻用するが、 意味 は participant と 同義。 `bridge / client / plugin` は 機能用途 で 使い分け、 participant の 区分名 では ない。

## register 慣習

bridge は 起動後 に `mcp__agent-hub__register` ツール で 自分 の `display_name` に **役割 を 簡潔 に 記載** する。

format:
```
<役名> — <1 行要約>
```

例:
- `Researcher — queue-based issue investigation`
- `Reviewer — code review`
- `Planner — ecosystem scheduler / task assignment`
- `Writer — note 連載 / docs 執筆`
- `Operator — bridge lifecycle + inventory`

`get_participants` 一覧 で 各 peer の 役割 を 一目 で 把握 できる ように する ため。 起動時 の `--display-name` CLI 引数 は 初期値、 `register` 呼び出し で 上書き する。 役割 が 変わったら 都度 `register` で 更新。

## 権限境界 (L0 / L1 / L2)

ecosystem 共通 の 権限階層。 各 role は 本 階層 を ベース に、 自分 の 役割 scope に 合わせて L0/L1 の 具体例 を 自 role の CLAUDE.md で 上書き 定義 する。

### L0 — 自律実行 (operator 確認不要)

- 自分 の 領分 に 閉じた observe / report / triage / 整理系 の 作業
- 既存 PR / issue の cross-link / status 追跡
- 自分 の archive (`feedback-archive/` / `research-archive/` / `planning-archive/` 等) への audit trail 記録

### L1 — operator に 確認 してから 実行

- **コード変更 を 伴う 実装** task の 開始指示 や 着手
- 新規 bridge の spawn / 不要 bridge の stop 依頼
- 複数 peer を またぐ 調整
- 影響範囲 が 自分 の 領分 を 超える 判断

### L2 — 人間 のみ

- 外部サービス へ の **重大な** 影響 が ある 操作
- 設計 の 最終確定 (= α/β/γ 選択 など、 operator/reviewer 経由 で 人間 に 問う)
- 既存 repo の visibility toggle / delete

迷ったら L1 扱い。 判別境界 が 曖昧 な 場合 は operator に 確認 してから 進める (= ecosystem 原則「不明点は推測で進めない」)。

## workdir 境界

各 role の編集権限範囲を明示する。

| 場所 | 権限 |
|---|---|
| 自 role の `<role>/` 配下 | 自由に編集・commit・merge (= L0) |
| 他 role の `<role>/` 配下 | 読み取りのみ。変更は当該 role に DM 依頼 |
| impl コード (`agent-hub/` 等) | 読み取りのみ。変更は当該 impl peer に DM 依頼 |

### impl peer PR の merge フロー

impl peer が出した PR は以下の順序を必須とする:

1. **reviewer LGTM ✅** — reviewer が PR に `LGTM ✅` コメント
2. **planner merge** — planner が LGTM 確認後に self-merge

reviewer LGTM なし → planner は merge しない。  
planner GO なし → impl peer 自身は merge しない。

## git 運用規約

**このリポジトリは main 直接 push**。feature branch は使わない。

- **branch を切ってはいけない** — doc-only monorepo で各 role が別 workdir を持つため、branch を切ると他 role の workdir が消えたり merge conflict が発生して迷惑になる
- **PR は出さない** — impl コードではないため reviewer / planner 経由の merge フローは不要
- **直接 main に commit + push** — 自 role の `<role>/` 配下の変更は即 main へ
- **レビューが必要な場合**: `<file>-draft.md` を作成して @reviewer に DM → LGTM が出たら draft を消して本ファイルに反映し main push

## archive 規約

各 role は 自分 の 成果物 (= review report / 調査結果 / planning report 等) を **archive dir に 1 ファイル / 1 件** で 保存 する。

| role | archive dir | ファイル名規約 |
|---|---|---|
| reviewer | `feedback-archive/` | `YYYY-MM-DD-<対象>.md` |
| planner | `planning-archive/` | `YYYY-MM-DD-<対象>.md` |
| researcher | `research-archive/` | `YYYY-MM-DD-<対象>.md` |
| writer | `drafts/` または 依頼元 repo の `articles/` 配下 | 依頼元 repo の 規約 に 従う |
| operator | `daily/` (= 任意、 運用ログ 用途) | `YYYY-MM-DD.md` |

### 共通原則

- **source of truth は archive 側**: agent-hub DM で 送る report と archive 内 の ファイル は **同一テキスト** が 原則。 先 に archive に 書いて から DM 送信 する
- **依頼元 の 明示**: archive 冒頭 (または PR body の「依頼元」欄) に **DM ID** または **依頼者** を 記載 する
- **既存スタイル の 尊重**: 各 role の template (= `REVIEW_TEMPLATE.md` / `RESEARCH_TEMPLATE.md` 等) が あれば、 それ に 沿う

## ecosystem 共通 行動指針

(= `プロジェクトの CLAUDE.md` の Conventions section から 抜粋、 fork 先 でも 維持 推奨)

- **Issues**: 全て の issue は GitHub Issues に 起票 する。 ecosystem-wide は `<your-org>/agent-hub`、 role-specific は 該当 repo
- **Issue driven**: 新機能 ・ 設計変更 ・ バグ修正 は 必ず issue を 起点 に する。 issue なしで PR を 立てない
- **不明点 は 推測 で 進めない**: 要件 ・ 仕様 ・ 判断 が 不明 な 場合 は 推測 で 実装 せず、 request 元 に 確認 してから 進める
- **GitHub が 正本**: 状態変化 (review / merge / close) は GitHub 上 に 記録 する。 DM は 通知手段 で あり、 merge 判断 の 根拠 に しない
- **起動時 register**: bridge は 起動後 すぐ に 自分 の `display_name` に 役割 を 簡潔 に 記載 (= 上記 register 慣習)

## fork 後 の カスタマイズ ポリシー

このファイル は **template の 初期値** です。 fork 先 では:

- **自由 に 編集 して 構わない** (= ecosystem 規約 を 自分 の 運用 に 合わせて 調整)
- 「**ecosystem-wide な 共通理解**」 として 還元 したい 改善 は **upstream (<your-org>/agent-hub-roles) に PR** で 提案
- 自分 の fork 固有 の カスタマイズ (= 個人 の workflow、 ローカル path、 個別 規約) は upstream に 還元 する 必要 なし

## 関連 repo

| repo | 役割 |
|---|---|
| [agent-hub](https://github.com/<your-org>/agent-hub) | server (TypeScript + SQLite + MCP) |
| [agent-hub-bridges](https://github.com/<your-org>/agent-hub-bridges) | engine 層 monorepo (Claude / Slack / Gemini / A2A) |
| [agent-hub-sdk](https://github.com/<your-org>/agent-hub-sdk) | Python client SDK (bridges が 依存) |
| **agent-hub-roles** (= 本 repo) | **persona 層 monorepo (本 ファイル)** |

## 関連 issue

- epic: <your-org>/agent-hub-roles#<N> (fork 後に自分の issue 番号を記入)
