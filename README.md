# agent-hub-roles

> 🚧 pre-alpha (M0 進行中、 issue [#1](https://github.com/kishibashi3/agent-hub-roles/issues/1) 参照)

[agent-hub](https://github.com/kishibashi3/agent-hub) の **persona 層 doc-only monorepo**。
各 role (reviewer / planner / researcher / writer-ja / writer-en / operator) の persona doc + workspace template を 1 つの repo に集約し、 **GitHub Template Repository** として fork して使う。

## fork モデル

```
agent-hub-roles (upstream template、 本 repo)
    │
    │ "Use this template" or fork
    ▼
my-agent-hub-roles (= 自分 の 運用 workspace)
    ├── 各 role の CLAUDE.md (= upstream から)
    └── feedback-archive/ / planning-archive/ / research-archive/ (= 自分 の 運用 で 育つ)
```

### 使い方

1. **fork** (推奨: "Use this template" ボタン)
   - GitHub の本 repo ページから "Use this template" → "Create a new repository"
   - もしくは `gh repo create my-agent-hub-roles --template kishibashi3/agent-hub-roles --private`
2. **自分 の fork で 運用** (= `feedback-archive` 等 が 育つ)
3. **upstream に 還元 したい 学び** が あれば、 fork から PR を 出す

upstream 側 は ecosystem-wide な 共通規約 (= `CLAUDE.md` の terminology / L0-L2 / register / archive) と 各 role の base persona doc を 提供。 個人 fork 側 は そこ に 自分 の 運用 ログ を 重ねる。

## 含まれる role

| role | 概要 | 上流 live workspace (= 私 の 運用 sample) |
|---|---|---|
| **reviewer** | PR / diff / file レビュー、 `@reviewer` peer | [`private/agent-hub-reviewer`](https://github.com/kishibashi3/agent-hub-reviewer) |
| **planner** | 計画 / 割り振り / merge 判断、 `@planner` peer | [`private/agent-hub-planner`](https://github.com/kishibashi3/agent-hub-planner) |
| **researcher** | issue 調査 / 要約、 `@researcher` peer | [`private/agent-hub-researcher`](https://github.com/kishibashi3/agent-hub-researcher) |
| **writer-ja** | note 連載 / docs 執筆（日本語）、 `@writer-ja` peer | `writer-ja/` (本 monorepo 内、 旧 `agent-hub-bridge-writer` は M5 で archive 済) |
| **writer-en** | note 連載 / docs 執筆（英語）、 `@writer-en` peer | `writer-en/` |
| **operator** | bridge lifecycle + inventory 管理 (= 人間 が 使う Claude Code セッション、 bridge ではない) | `private/operation/` |

> **writer-ja / writer-en** は M5 (2026-05-21) で本 monorepo へ移行完了。旧 `agent-hub-bridge-writer` / `agent-hub-bridge-writer-en` は archive 済み。
> 他 role (reviewer / planner / researcher) の旧 per-role repo は引き続き並行稼働中 (monorepo への移行は 今後の milestone で 実施予定)。

## quick-start (= fork した workspace を 起動 する)

### 前提 (= 一度だけ install)

> ⚠️ **`scripts/start.sh` は bash 4+ を要求** します (= associative array 使用)。 macOS の bundled `/bin/bash` は 3.2 系のため、 macOS user は `brew install bash` で Homebrew bash を入れて、 Apple Silicon は `/opt/homebrew/bin/bash scripts/start.sh ...`、 Intel Mac は `/usr/local/bin/bash scripts/start.sh ...` で起動するか、 PATH を 通して `bash scripts/start.sh ...` してください。 Linux は 通常 4+ なので そのまま 動作します。

```bash
# 1. bash 4+ の確認 (= macOS user 必須、 Linux は 通常 OK)
bash --version    # → GNU bash, version 4.x or 5.x ...

# 2. agent-hub-bridges[claude] を install (= bridge spawn 用 コマンド を 提供)
pip install "agent-hub-bridges[claude] @ git+https://github.com/kishibashi3/agent-hub-bridges.git"

# 3. env を ~/.bashrc / ~/.zshrc に export
export AGENT_HUB_URL="https://your-agent-hub.example.com/mcp"
export GITHUB_PAT="ghp_..."           # read:user scope
export AGENT_HUB_USER="operator"      # この shell の Claude Code を @operator として register
export AGENT_HUB_TENANT="your-tenant" # 任意

# 4. (任意) scripts/operator-env.sh.example を copy + 編集 + source も可
```

### 起動

```bash
cd <your-agent-hub-roles-fork>

./scripts/start.sh                         # operator のみ (= Claude Code 起動案内、 default)
./scripts/start.sh all                     # 4 role bridge を background spawn + operator 案内
./scripts/start.sh reviewer planner        # 個別 / 複数 指定
./scripts/start.sh --help                  # usage 表示
```

各 role は [`agent-hub-bridges[claude]`](https://github.com/kishibashi3/agent-hub-bridges) の 上 に 乗る persona layer:
- **reviewer / planner / researcher / writer-ja / writer-en**: `agent-hub-bridge-claude --user <role>` で 別 process 起動 (= 自動応答 bridge worker)
- **operator**: `claude` (= Claude Code 本体、 agent-hub-plugin 経由 で `@operator` として register、 `operator/` ディレクトリ から 起動)

operator setup の 詳細 は [`operator/CLAUDE.md`](./operator/CLAUDE.md) 参照。

## 構造

```
agent-hub-roles/
├── CLAUDE.md                 # 共通ルール (ecosystem 用語 / L0-L2 / register / archive)
├── README.md                 # 本ファイル
├── CHANGELOG.md              # M0+ の変更履歴
├── reviewer/
│   ├── CLAUDE.md             # reviewer persona
│   ├── REVIEW_TEMPLATE.md
│   ├── REVIEW_CRITERIA.md
│   ├── REVIEW_FRAMEWORK.md
│   └── feedback-archive/.gitkeep
├── planner/
│   ├── CLAUDE.md
│   └── planning-archive/.gitkeep
├── researcher/
│   ├── CLAUDE.md
│   ├── RESEARCH_TEMPLATE.md
│   └── research-archive/.gitkeep
├── writer-ja/
│   └── CLAUDE.md
├── writer-en/
│   └── CLAUDE.md
├── operator/
│   └── CLAUDE.md
├── scripts/
│   ├── start.sh              # role 起動 wrapper (operator default / all / role-list)
│   └── operator-env.sh.example  # operator 用 env template (= copy + 編集 + source)
└── .github/workflows/ci.yml
```

## 兄弟 repo (ecosystem)

| repo | 役割 |
|---|---|
| [agent-hub](https://github.com/kishibashi3/agent-hub) | server (TypeScript + SQLite + MCP) |
| [agent-hub-bridges](https://github.com/kishibashi3/agent-hub-bridges) | engine 層 monorepo (Claude / Slack / Gemini / A2A) |
| [agent-hub-sdk](https://github.com/kishibashi3/agent-hub-sdk) | Python client SDK |
| **agent-hub-roles** (= 本 repo) | **persona 層 monorepo** |

## 開発 (= upstream への 還元)

```bash
git clone git@github.com:kishibashi3/agent-hub-roles.git
cd agent-hub-roles

# markdown link check (CI と 同じ)
# (ローカル 確認用 ツール は CI workflow を 参照)
```

## ライセンス

Apache-2.0

## 関連 issue

- epic: [#1](https://github.com/kishibashi3/agent-hub-roles/issues/1)
- M0: [#4](https://github.com/kishibashi3/agent-hub-roles/issues/4)
