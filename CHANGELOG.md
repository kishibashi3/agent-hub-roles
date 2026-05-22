# Changelog

All notable changes to `agent-hub-roles` are documented here. Follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) loosely; ecosystem-internal so dates use UTC and version numbers track milestones rather than semver.

## [Unreleased] — 2026-05-19 (M2.1)

### Fixed (M2.1 — Intel Mac Homebrew bash path、 issue [#10](https://github.com/kishibashi3/agent-hub-roles/issues/10))

- `scripts/start.sh` の error message + `README.md` quick-start callout に Intel Mac の Homebrew bash path (`/usr/local/bin/bash`) を 追記 (= 既存は Apple Silicon `/opt/homebrew/bin/bash` のみだった)
- 依頼元: @reviewer M2 PR #9 LGTM Minor 1 + @planner DM `1f91cad3-...` (= 両者 から 同じ 指摘、 採否 author 判断 → 採用)

## [Unreleased] — 2026-05-19 (M2)

### Fixed (M2 — scripts/start.sh bash 4+ compat、 issue [#8](https://github.com/kishibashi3/agent-hub-roles/issues/8))

- `scripts/start.sh`: bash version guard を 冒頭に追加 (= `BASH_VERSINFO[0] < 4` で fail-fast)。 macOS の bundled `/bin/bash` (= 3.2 系) で associative array 由来の cryptic error を 避けて、 actionable な hint (= `brew install bash`) を 出す
- `README.md` quick-start に **bash 4+ 要件** を 明示 + macOS user 向け Homebrew bash 案内
- 依頼元: @reviewer M1 PR #7 LGTM 内 Minor 1 + @planner DM `4dff30db-...` GO 確認

## [Unreleased] — 2026-05-19 (M1)

### Added (M1 — start.sh + operator plugin register setup、 issue [#6](https://github.com/kishibashi3/agent-hub-roles/issues/6))

- `scripts/start.sh` — role 起動 wrapper:
  - 引数なし → operator setup 案内 (= bridge ではない、 Claude Code 起動手順 を 表示)
  - `all` → operator 案内 + 4 role bridge を background spawn (`agent-hub-bridge-claude --user <role> --workdir <fork>/<role>/`)
  - `<role>...` → 個別 / 複数 指定
  - `--help` → usage 表示
  - tenant: `AGENT_HUB_TENANT` env から読む、 未設定 warning
  - server check: `AGENT_HUB_URL` への curl ヘルスチェック、 未起動 warning (= start.sh は server 起動 しない)
  - prereq: `agent-hub-bridge-claude` not in PATH → fail-fast
- `scripts/operator-env.sh.example` — operator 用 env template (= fork ユーザー が `~/.agent-hub-operator.env` に copy + 編集 + source)
- `operator/CLAUDE.md` の セットアップ section 拡充 (= agent-hub-plugin install 手順 + `AGENT_HUB_USER=operator` env + Claude Code 完全終了 再起動 注意点 + `/mcp` 接続確認 + bridge spawn flow)
- `README.md` quick-start を 新 setup flow (= env export + scripts/start.sh) に 更新

## [Unreleased] — 2026-05-19 (M0)

### Added (M0 — doc-only monorepo bootstrap、 issue [#4](https://github.com/kishibashi3/agent-hub-roles/issues/4))

- `CLAUDE.md` (root) — ecosystem 共通 規約 (用語 / register / L0-L2 / archive 規約 / 行動指針)
- `README.md` — fork モデル + GitHub Template 使い方 + 5 role 一覧 + sibling repos
- `reviewer/` — 上流 `private/agent-hub-reviewer` から snapshot (= `CLAUDE.md` + `REVIEW_TEMPLATE.md` + `REVIEW_CRITERIA.md` + `REVIEW_FRAMEWORK.md` + `feedback-archive/.gitkeep`)
- `planner/` — 上流 `private/agent-hub-planner` から snapshot (= `CLAUDE.md` + `planning-archive/.gitkeep`)
- `researcher/` — 上流 `private/agent-hub-researcher` から snapshot (= `CLAUDE.md` + `RESEARCH_TEMPLATE.md` + `research-archive/.gitkeep`)
- `writer/CLAUDE.md` — 上流 `private/agent-hub-bridge-writer` から snapshot
- `operator/CLAUDE.md` — 新規執筆 (= `private/operation/CLAUDE.md` を参考に template として書き起こし)
- `.github/workflows/ci.yml` — markdown link check + yaml lint
- GitHub Template Repository flag: ON (= 2026-05-19T22:09Z 設定)

### Changed

- 設計方針 pivot: 旧方針 (Python package + extras_require) を 全面破棄、 **doc-only monorepo + GitHub Template** に 変更 (= operator DM `f46989d7-...` + `0e87f587-...` で 確定)
- operator handle 統一: `@ope-ultp1635` / `@ope-*` 系 表記 を **`@operator`** に 全置換 (= 5 role の 命名規則 統一、 operator DM `bbd7df92-...` 2026-05-19T22:18Z)

### Closed (superseded)

- 旧 issue [#2](https://github.com/kishibashi3/agent-hub-roles/issues/2) — M0 Python package 版
- 旧 PR [#3](https://github.com/kishibashi3/agent-hub-roles/pull/3) — Python package 実装

## [milestone roadmap]

- **M0** (= 完了): doc-only monorepo bootstrap (5 role snapshot + root CLAUDE.md + README + CHANGELOG + CI)
- **M1** (= 完了): `scripts/start.sh` + `scripts/operator-env.sh.example` + operator plugin register setup
- **M2** (= 本 entry): scripts/start.sh bash 4+ compat fix
- **M3+** (= 未定): persona doc lint / 各 role の 充実 iteration / 旧 per-role repo の docs 還流 finalize (= scope 別 issue + operator 確認)
