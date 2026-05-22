# RESEARCH_TEMPLATE.md

`@researcher` が出す **draft PR body** と **research-archive 保存ファイル本文** の正本 format。
1 調査 = 1 PR = 1 archive ファイル。両者は同一テキストが原則。

---

## 使い方

1. 調査着手時に下記テンプレを branch の PR body にコピペ
2. 各セクションを埋める
3. PR を **draft** で起票
4. 同じテキストを `research-archive/YYYY-MM-DD-<対象>.md` にも保存
5. 依頼者に DM 通知

---

## テンプレ本体

````markdown
---
date: 2026-05-18                        # 着手日 (YYYY-MM-DD)
issue: agent-hub#26                     # 元 issue 識別子 (= <repo>#<N> 形式)
                                        # issue が無い場合は target を使う (例: target: "design-collaboration-model")
requester: "@ope-ultp1635"              # 依頼者 (agent-hub handle)
scope: focused                          # focused / cross-cutting / exploratory
conclusion-type: facts-only             # facts-only / comparison / recommendation
tags: [presence, last_active_at, M1]    # 自然語タグ + project 内 milestone / section ID
related_issues: [agent-hub#27]          # follow-up 候補や関連 issue (任意)
related_prs: [agent-hub#14]             # 関連 PR (任意)
elapsed: 1h 20m                         # 着手→完了の経過
methods: [code-read, gh-issue]          # 調査手段 (code-read / gh-issue / gh-pr / web-search / web-fetch 等)
---

# Research: <調査対象の短い見出し>

**依頼**: <依頼内容を 1-2 行で>
**結論種別**: 事実整理 / 比較 / 推奨

## TL;DR (3 行)

- <結論 1>
- <結論 2>
- <結論 3>

**Self-check**: 完了 (TL;DR ≤3 行 / 三段階ラベル使用 / 出典添付 / 依頼者明示 / 調査スコープ記載)

---

## 1. 背景 / 依頼内容

依頼の経緯と、調査の "終わり" の定義(= どこまで掘ったら完了とするか)。

## 2. 事実 (三段階ラベル: 確認済み / 推定 / 未検証)

各項目に **file:line / commit / issue / PR / URL** を必ず添える。  
ラベル: **[確認済み]** = ファイル・commit を直接読んで確認 / **[推定]** = 設計意図・周辺コードからの類推 / **[未検証]** = 実行・実測未確認。

- [確認済み] <事実 1> — `path/to/file.ts:42`
- [推定] <事実 2> — commit `abc1234` ("...") から類推
- [未検証] <事実 3> — agent-hub#14 (author: @xxx, 2026-05-10)、実動作未確認

## 3. 設計意図 / 経緯 (= why)

commit message / PR / issue / コメントから抽出。出典必須。

- <なぜこうなっているか> — `<出典>`

## 4. 影響範囲

Grep / Glob で網羅した範囲。

| 影響先 | 種別 | 備考 |
|---|---|---|
| `src/foo.ts:120` | code | <…> |
| `docs/X.md` | doc | <…> |
| agent-hub#15 | issue | <…> |

## 5. 既知の議論 (時系列)

関連 issue / PR で誰が何を主張したか。

- 2026-05-10 — @author: "<主張>"(agent-hub#14)
- 2026-05-12 — @reviewer: "<反論>"(agent-hub#14 comment)

## 6. オプション比較 (= 該当する場合のみ)

複数案がある場合は表で並べる。

| 案 | 内容 | 長所 | 短所 | 影響範囲 |
|---|---|---|---|---|
| A | <…> | <…> | <…> | <…> |
| B | <…> | <…> | <…> | <…> |

## 7. 推奨 (= 依頼者が望む場合のみ)

> ⚠️ これは **現時点での推奨** であり、断定ではない。
> 反対意見と未調査要因をセットで明示する。

- **推奨**: 案 X
- **根拠**: <…>
- **反対意見 / 懸念**: <…>
- **前提**: <この前提が崩れたら推奨は変わる>

## 8. 未調査 / Follow-up 候補

調査範囲外だが気になった点、追加調査候補。

- <未調査項目 1> — 推測: <…>
- <Follow-up 候補> — 別 issue 起票候補

## 9. 参考資料

- `path/to/file.ts:42`
- agent-hub#14
- commit `abc1234`
- <https://example.com/...>

---

**Refs**: #<issue-id>
````

---

## 書き方のルール

- **三段階ラベルを使用**: 「2 章=事実」は各項目に **[確認済み] / [推定] / [未検証]** を明示。「7 章=推奨」は「現時点での」を冠する
- **出典必須**: file:line / commit hash / issue/PR 番号 / URL のいずれかを必ず添える
- **未調査は隠さない**: わからなかったことは 8 章に「未調査」と明示
- **依頼範囲を超えない**: 気になる関連事項は 8 章「Follow-up 候補」に書き、本論を膨らませない
- **frontmatter は必須最小**: `date / issue (or target) / requester` の 3 fields は最低限埋める

## 命名規約 (archive ファイル)

```
research-archive/YYYY-MM-DD-<対象>.md
```

- 日付は **着手日**
- `<対象>` は識別しやすい kebab-case。issue なら `<repo>-N-<slug>`、テーマなら `<slug>`
- 例:
  - `research-archive/2026-05-18-agent-hub-researcher-1-initial-setup.md`
  - `research-archive/2026-05-20-last-active-at-design.md`
