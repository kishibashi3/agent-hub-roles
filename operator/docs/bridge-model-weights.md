# Bridge Model Weights

bridge spawn 時にタスクの性質に応じてモデルを選ぶ設計。

## Weight 定義

| weight | タスク | 対象 |
|---|---|---|
| `heavy` | design, review, 人間 UI | reviewer, 設計フェーズ, operator (人間と直接やりとりする Claude) |
| `middle` | impl, debug, 調査 | 実装・デバッグフェーズの bridge worker, researcher |
| `light` | operation routing, 単純整理 | 単純 relay, client 系, knowledge (受け取って整理して commit するだけ) |

## 使い方

```bash
/spawn-bridge --user reviewer --weight heavy
/spawn-bridge --user agent-hub-impl --weight middle
```

デフォルトは `middle`。

## マッピング管理

weight → model 名のマッピングは `.bashrc` の env var で持つ。
モデル名をコードにハードコードしない。新モデルが出たら env var を更新するだけ。

```bash
export AGENT_HUB_BRIDGE_MODEL_HEAVY="claude-opus-4-7"
export AGENT_HUB_BRIDGE_MODEL_MIDDLE="claude-sonnet-4-6"
export AGENT_HUB_BRIDGE_MODEL_LIGHT="claude-haiku-4-5"
```

`spawn-bridge.sh` が `--weight` を受けて env var を引き、`ANTHROPIC_MODEL` として bridge プロセスに渡す。

## 実装状況

- [ ] `spawn-bridge.sh` に `--weight` フラグ追加
- [ ] `ANTHROPIC_MODEL` が bridge-claude 内部の `claude` CLI に伝搬するか確認 (@bridge-claude-impl)
- [ ] `.bashrc` に model mapping env var 追加
