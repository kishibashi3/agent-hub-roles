# Review Report Template

> `@reviewer` の出力 format 正本。レビューを書くときは このテンプレを **必ず** 使う。
> 観点の優先順は `CLAUDE.md` の「レビュー観点」を参照。

## 使い方

1. 1 件のレビューにつき 1 ファイル。
2. 保存先: `feedback-archive/YYYY-MM-DD-<対象>.md` (例: `feedback-archive/2026-05-16-PR-14-get-participants-team-metadata.md`)
3. 同じ内容を `mcp__agent-hub__send_message` で依頼元に送る。**ファイル と message は同一テキスト** が原則 (= source of truth は archive 側)。
4. 「気持ち / 好み」で書くものは必ず `💡 Suggestion` 段で、その旨を明示する。

---

## テンプレート (= ここから下をコピーして使う)

```markdown
# Review: <対象>

**結論**: LGTM / LGTM (with Minor) / Request Changes / Discussion needed

**サマリ**: 1-3 行で全体の印象。「何が良くて、何が引っかかったか」を短く。

**着手**: `YYYY-MM-DDTHH:MM:SSZ` (UTC、依頼受領 + 着手判断した時刻)
**完了**: `YYYY-MM-DDTHH:MM:SSZ` (UTC、report を `send_message` した時刻)
**所要**: `<経過時間 e.g. 2h 15m>` (= 2026 best practice #2 「first review < 6h」の自己 SLA 計測の起点。超過時は理由を「未確認 / フォロー要」に明記)

---

## 🔴 Critical (= blocker、修正必須)

### 1. <短い見出し>
- `<file>:<line>` (= 必ず file:line を添える)
- 何が問題か (= 観察できる事実だけ書く)
- なぜ問題か (= 根拠。CLAUDE.md / 規約 / セキュリティ原則 / 既存 pattern との不一致 等)
- 改善案 (= 提案、強制ではない。複数案あれば列挙)

(該当なしなら「なし。」と 1 行で書く)

## 🟡 Minor (= 改善推奨、ただし block しない)

### 1. <短い見出し>
(同形式)

## 💡 Suggestion (= 議論余地、好み)

### 1. <短い見出し>
(同形式、`💡` であることを意識した tone)

---

## 設計 docs 整合性 (= 必要な PR でだけ)

対象プロジェクトの design doc / CLAUDE.md / ARCHITECTURE.md と矛盾していないか、または「整合」を一言。

## Breaking change 影響範囲 (= 該当 PR でだけ)

`grep` で確認した consumer 一覧と、それぞれの追従要否。

---

**確認した範囲**:
- ✅ Security
- ✅ Correctness
- ⚠️ Performance (時間制約で一部のみ)
- ✅ Readability
- ⚠️ Test coverage
- ✅ Consistency

**未確認 / フォロー要**:
- <該当があれば書く。なければ「特になし」>

**手元検証 (= 該当する場合)**:
- `npm run typecheck`: clean / N errors
- `npm test`: N files / M tests passed (regression なし)
- (もしくは「test 実行は依頼元の許可待ち」)
```

---

## 結論ラベルの使い分け

| ラベル | 意味 | 目安 |
|---|---|---|
| **LGTM** | 問題なし、merge OK | Critical 0、Minor 0-1、軽微な Suggestion のみ |
| **LGTM (with Minor)** | merge して良いが、Minor / Suggestion の採否は author 判断 | Critical 0、Minor 1-3 |
| **Request Changes** | Critical あり、merge 前に修正必須 | Critical >= 1 |
| **Discussion needed** | 設計判断が必要、reviewer 単独では結論出せない | scope / direction を author / operator に確認したい場合 |

## 観点ごとの ✅ / ⚠️ / ❌

- **✅** = 確認した上で問題なし
- **⚠️** = 確認したが時間 / 範囲制約で部分的、or 懸念あり
- **❌** = 確認していない (= 依頼範囲外、or skip した)

「⚠️」「❌」は **理由を「未確認 / フォロー要」セクションに書く** こと。沈黙は dishonesty。

## 関連

- 振る舞いの正本: [CLAUDE.md](./CLAUDE.md)
- ecosystem 統合 judgment axis: [REVIEW_CRITERIA.md](./REVIEW_CRITERIA.md)
- 過去のレビュー履歴: [feedback-archive/](./feedback-archive/)
