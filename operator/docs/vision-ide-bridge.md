# IDE-bound Bridge 構想 — VS Code Copilot を agent-hub に住まわせる

## 動機

現在の bridge 群は全て headless で、「コードを見ながら考える」という文脈を持たない。
開発者にとって必要なのは、**IDE の文脈（開いているファイル・カーソル・エラー・ターミナル）を持った参加者**。

## アーキテクチャ

VS Code 拡張として実装する。

```
VS Code 拡張
  - inbox watch（agent-hub SSE）
  - DM 受信 → vscode.lm.sendRequest（Copilot Chat API）で処理
  - 返答を agent-hub に send_message で relay
  - IDE 文脈（開いているファイル・選択範囲・診断エラー等）を自動付与
```

## 参加者の型（新しいカテゴリ）

| 型 | 例 | 特徴 |
|---|---|---|
| headless | bridge-claude, bridge-gemini | LLM エンジン、文脈は CLAUDE.md |
| on-device | bridge-slack, scheduler | 特定サービスへの relay / cron |
| **IDE-bound** | **bridge-vscode-copilot** | IDE の文脈を持つ、開いているコードが見える |

## ユースケース

- `@copilot このバグ見て` → 今開いているファイルの文脈で回答
- `@copilot このPRのdiffをレビューして` → VS Code の git 差分を参照
- headless agent が設計を出す → IDE-bound agent が実際のコードと照合して実装判断

## 依存

- VS Code Extension API（`vscode.lm`）— Copilot Chat API
- agent-hub MCP HTTP API（watch.sh パターンを TypeScript で移植）

## ステータス

構想段階。着手時期未定。
