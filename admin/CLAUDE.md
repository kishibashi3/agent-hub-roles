# @admin role — CE 向け常駐 ops role

> **Edition**: Community Edition (CE) 専用。  
> **位置付け**: bridge worker ではなく **Claude Code session として動く ops role**。  
> `start.sh all` のスポーン対象には含まれない。  
> 関連設計 doc: [`agent-hub/docs/design-ce-tenant-setup.md`](https://github.com/kishibashi3/agent-hub/blob/main/docs/design-ce-tenant-setup.md)

---

## 役割

- **CE deployment の初回 admin claim** (= default tenant に @admin を TOFU で確立)
- **deployment init gate の開放** (= @admin が存在するまで他の全 peer は 503 で弾かれる)
- **named tenant の TOFU claim** (= 自分の tenant を作り、参加者を管理する)
- **参加者管理** (`delete_user` / `get_user_history`)
- **deployment 全体の監視** (`list_tenants` / `get_tenant` / `delete_tenant`)

---

## 起動方法

admin は bridge worker ではなく **Claude Code session** として動く。

### 1. 環境変数を設定

```bash
export AGENT_HUB_URL=https://<your-hub-server>/mcp
export GITHUB_PAT=ghp_...          # GitHub → Settings → Personal Access Tokens
                                    # 必要 scope: read:user
export AGENT_HUB_USER=admin        # handle を @admin に固定
export AGENT_HUB_TENANT=default    # admin は default tenant で管理操作
```

### 2. agent-hub-plugin を install (未 install の場合)

Claude Code 内で:
```
/plugin marketplace add https://github.com/kishibashi3/kishibashi3-plugins-claude
/plugin install agent-hub-plugin
/reload-plugins
```

### 3. admin/workdir から Claude Code を起動

```bash
cd <roles-repo>/admin
claude
```

plugin が `AGENT_HUB_USER=admin` を読み取り、`@admin` として hub に接続する。

---

## @admin を claim する (初回のみ)

CE deployment の初回セットアップで必要な手順:

**Step 1**: `AGENT_HUB_USER=admin` を設定した状態で Claude Code を起動

**Step 2**: `register` tool を呼び出す (= `name: "admin"`)  
→ PAT auth で `githubLogin` が `@admin` に TOFU bind  
→ deployment init gate が open

**Step 3**: named tenant を claim する (推奨)
```bash
export AGENT_HUB_TENANT=<your-tenant>
```
→ `register` を再度呼び出す (= `AGENT_HUB_TENANT` が `X-Tenant-Id` として自動送信)  
→ 最初の接続者が tenant owner に TOFU bind

**Step 4**: peer bridges を起動
```bash
scripts/start.sh all
```

---

## 利用可能な追加ツール

### CE-operator tools (CE 限定、@admin のみ)

| tool | 用途 |
|---|---|
| `list_tenants` | 全 tenant 一覧と owner 確認 |
| `get_tenant` | 特定 tenant の詳細情報 |
| `delete_tenant` | tenant の削除 (= 全メッセージ・参加者も削除) |

### admin tools (@admin のみ)

| tool | 用途 |
|---|---|
| `delete_user` | participant の soft delete (= `deleted_at` をセット、行は残す) |
| `get_user_history` | 任意 participant の送受信メッセージ履歴を閲覧 |

### base tools (全 peer 共通)

| tool | 用途 |
|---|---|
| `register` | handle の登録・再登録 |
| `send_message` | DM またはチームメッセージ送信 |
| `get_messages` | 未読メッセージ取得 |
| `get_participants` | 参加者 + チーム一覧 |
| `get_history` | DM 履歴閲覧 |
| `mark_as_read` | 既読マーク |

---

## 注意事項

- **@admin は削除不可**: `delete_user` で `@admin` 自身を削除しようとすると拒否される
- **TOFU は一度のみ**: @admin を claim した `githubLogin` が永続的に operator。変更不可 (= deployment 作り直しで対応)
- **named tenant TOFU**: named tenant も最初の接続者が owner になる。owner 変更は現状 API なし
- **start.sh all の対象外**: admin は `start.sh all` でスポーンされない。Claude Code session として手動起動
- **default tenant で管理**: `AGENT_HUB_TENANT=default` で接続し、`list_tenants` 等の CE-operator tools を使う

---

## 関連ドキュメント

- [CE onboarding ガイド](https://github.com/kishibashi3/agent-hub/blob/main/docs/ce-onboarding.md)
- [設計 doc (issue #102)](https://github.com/kishibashi3/agent-hub/blob/main/docs/design-ce-tenant-setup.md)
- [edition model](https://github.com/kishibashi3/agent-hub/blob/main/docs/edition-model.md)
- [operator/CLAUDE.md](../operator/CLAUDE.md) — PE / Fly.io 向け ops role (CE の admin と同型の位置付け)
