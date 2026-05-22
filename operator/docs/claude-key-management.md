# Claude API Key Management

## デフォルトキー

`~/.claude/settings.json` の `ANTHROPIC_API_KEY` がグローバルデフォルト。
アカウント: your-email@example.com

## プロジェクト別キーの設定

`.claude/settings.local.json` をプロジェクトディレクトリに置く:

```json
{
  "env": {
    "ANTHROPIC_API_KEY": "sk-ant-..."
  }
}
```

- `settings.local.json` は `.gitignore` 済み — secret が repo に入らない
- `claude` 起動時に自動適用 (session 再起動が必要)
- 親ディレクトリに置くとサブディレクトリ全体に適用される

### 例: ntv 配下を別キーにする

```
app/private/ntv/.claude/settings.local.json
```

これで `ntv/` 以下のすべてのプロジェクトが NTV のキーを使う。

## 優先順位

Local > Project > User > Managed (高い順)

`.local.json` が最優先。
