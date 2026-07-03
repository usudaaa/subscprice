# サブスク料金ナビ

主要テック系サブスクリプションの現在価格と改定履歴をまとめるWebサイト（Impress Watchのコーナー想定）。
公開URL: https://usudaaa.github.io/subscprice/

## 構成

純粋な静的サイト。ビルドツール・フレームワークなし。

- `index.html` — 公開ページ。起動時に `data/db.json` をfetchして描画
- `edit.html` — 編集ツール。同じく `data/db.json` をfetchし、「保存して反映」で serve.ps1 の `POST /save` に送信
- `data/db.json` — **データの正本**（1行の圧縮JSON）。index/editは常にここを参照
- `serve.ps1` — ローカル開発用HTTPサーバー（PowerShell）。`POST /save` で db.json を上書き
- `.github/workflows/pages.yml` — mainへのpushでGitHub Pagesへ自動デプロイ（Actions方式。branch方式はデプロイ失敗が続いたため使わない）
- `index_0510_01.html` — 旧スナップショット。触らない

## データ構造（db.json）

```
{ "last_updated": "YYYY-MM-DD",
  "categories": [{id, name}],
  "services": [{ id, name, provider, categories: [カテゴリid配列],
                 url, url_label, description,
                 plans: [{ id, name, description,
                           price_history: [{ amount, currency: "JPY"|"USD", billing: "monthly"|"annual",
                                             tax_included, valid_from, valid_to, source, note }] }] }] }
```

- `categories` は**配列**（複数カテゴリ併存可。例: YouTube Premiumを動画+音楽に入れられる設計）
- `valid_to: null` = 現在有効な価格。**改定時は旧エントリの valid_to を必ず閉じて**新エントリを追加する
  （getCurrentPriceはvalid_from最新を選ぶフォールバックを持つが、データとしては閉じるのが正）
- `amount: 0` は「価格未確認」として表示される（プレースホルダーに使える）
- `last_updated` はedit.htmlの保存時に自動更新。スクリプトで直接編集した場合は手動で更新すること

## 編集ルール（最重要）

1. **出典の優先度**: ①サービス公式サイト ②Impress Watch（watch.impress.co.jp）③その他Watchシリーズ
   （PC Watch / ケータイ Watch / 窓の杜 / AV Watch / INTERNET Watch 等 impress.co.jp ドメイン）。
   ITmediaなど他媒体は出典に使わない
2. **出典に明記されていない数字を書かない**。自分で計算した税込額・換算額を出典付きデータとして
   記載しない（例:「消費税10%を徴収開始」はOK、記事にない「税込22ドル」はNG）
3. 価格のファクトチェックは必ずWeb検索・公式ページで裏取りし、出典URLをsourceに記録する
4. カッコは半角 `()` に統一（表示テキスト）
5. ドル建てサービスは「xx USドル(税別)」表記。**円換算は表示しない**（為替管理を避けるため。
   年額換算もドルのまま）。`USD_TO_JPY` は価格順ソートの内部計算専用
6. 文章のトーンはメディアの解説調（です・ます調ではなく体言止め混じりの記事調）。
   サービス概要は3〜4文で、プラン間の違い・固有の強み・旧サービス名の文脈を含める

## よくある作業

- **価格改定の反映**: edit.htmlの「💴 価格改定を記録」を使う（改定日・新価格・出典を入力すると
  旧エントリのvalid_toクローズと新エントリ追加を自動で行う）。手動の場合は旧エントリのvalid_toを
  改定前日で閉じてから新エントリを追加。直近12カ月以内の改定は一覧に値上げ/値下げバッジが自動表示される
- **ローカル確認**: `powershell -ExecutionPolicy Bypass -File serve.ps1`（ポート3000）→
  http://localhost:3000/ 。edit.htmlの「保存して反映」はserve.ps1経由でのみ動く（Pages上では動かない）
- **公開反映**: `git push origin main` だけ。Actionsが自動デプロイ（1〜2分）
- **db.jsonの一括編集**: PowerShellスクリプトで文字列置換する場合、**.ps1はUTF-8 BOM付きで保存**
  しないと日本語リテラルが壊れる（PowerShell 5.1）。編集後は `ConvertFrom-Json` で妥当性検証してから書き込む

## 今後の予定

- 完成時に全サービス・全プランのファクトチェックを実施（上記ルール1〜3に則って全出典を照合）
- 検討中の機能: 合計金額シミュレーター、今月の改定ニュース欄、サービス追加（読書系カテゴリ等）
- 将来的に技術担当へ引き継ぐ予定。暫定運用に固有の仕組み（GitHub API化・トークン管理など）は
  追加しない方針。引き継ぎ時は人間向けの仕様書（README）を整える
