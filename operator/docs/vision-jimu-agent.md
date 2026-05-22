# 事務処理自動化 agent 構想

## 動機

月次の稼働登録・案件工数入力など、定型的な web フォーム作業を人間が一切触らずに完結させたい。

## 構成イメージ

- **@jimu**（事務処理 agent）: bridge worker。Playwright スクリプトを実行する担当。workdir に各種事務処理スクリプトを持つ
- **scheduler**: 毎月何日に何をやるかを管理。時が来たら @jimu に send_message
- **月初確認**: @planner が今月の工数配分を Kazuhiro に確認 → 数字が決まったら scheduler に登録

## 使い方イメージ

```
# 月末 28 日 22 時に稼働登録
@scheduler add monthly-kintai 0 22 28 * * @jimu 稼働登録してください hours=160
```

## 依存

- scheduler add/delete/run_at（PR #67 merged ✅）
- Playwright or 同等のブラウザ自動化ライブラリ
- 対象 web サービスごとのスクリプト実装

## ステータス

構想段階。着手時期未定。
