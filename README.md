# サブスク料金ナビ — 技術仕様書（引き継ぎ用）

主要テック系サブスクリプションの現在価格と改定履歴をまとめるWebサイト。Impress Watchのコーナーとしての組み込みを想定したプロトタイプです。

- 公開URL: https://usudaaa.github.io/subscprice/
- 運用手順（編集者向け）: [docs/MANUAL.md](docs/MANUAL.md)
- 編集部確認の残項目: [docs/EDITORIAL_CHECK.md](docs/EDITORIAL_CHECK.md)
- AI（Claude Code）向け開発規約: [CLAUDE.md](CLAUDE.md)

## 1. アーキテクチャ

純粋な静的サイト。ビルドツール・フレームワーク・外部ライブラリ依存なし（Vanilla JS + インラインCSS）。

```
data/db.json（データの正本・1行の圧縮JSON）
   ├─ index.html  … 公開ページ。起動時にfetchして全描画
   └─ edit.html   … 編集ツール。fetchして編集し、serve.ps1のPOST /saveで書き戻す
```

| ファイル | 役割 |
|---|---|
| `index.html` | 公開ページ（HTML/CSS/JSすべて1ファイル） |
| `edit.html` | ローカル編集ツール（同上） |
| `data/db.json` | 全データ。**唯一の正本** |
| `serve.ps1` | ローカル開発用HTTPサーバー（PowerShell HttpListener、port 3000）。`POST /save`でdb.jsonを上書き |
| `.github/workflows/pages.yml` | mainへのpushでGitHub Pagesへデプロイ（actions/deploy-pages方式） |
| `images/` | OGP画像・favicon |
| `docs/` | 運用マニュアル・チェックリスト |
| `index_0510_01.html`, `*.bak*` | 旧スナップショット（参照用・触らない） |

※ fetchを使うため `file://` 直開きでは動作しない。必ずHTTPサーバー経由。

## 2. データ仕様（db.json）

```jsonc
{
  "last_updated": "YYYY-MM-DD",        // edit.htmlの保存時に自動更新
  "categories": [ { "id", "name" } ],  // 表示順そのまま
  "services": [
    {
      "id": "netflix",                 // 【不変】直リンク(#id)とシミュレーター記憶のキー
      "name", "provider",
      "categories": ["video"],         // 配列（複数カテゴリ併存可）
      "url", "url_label",              // 公式サイトリンク
      "affiliate_text", "affiliate_url", // 任意。両方あると詳細モーダルに加入ボタン表示
      "ended": "YYYY-MM-DD",           // 任意。サービス提供終了
      "description",                   // 記事調3〜4文。旧サービス名もここに（検索対象）
      "plans": [
        {
          "id", "name", "description",
          "ended": "YYYY-MM-DD",       // 任意。プラン提供終了
          "closed": true,              // 任意。新規受付終了（提供は継続）
          "price_history": [
            {
              "amount": 1590,          // 0 =「価格未確認」表示
              "price_label": "…",      // 任意。amount 0時の代替表示文字列
              "currency": "JPY"|"USD",
              "billing": "monthly"|"annual",
              "tax_included": true,
              "valid_from": "YYYY-MM-DD",
              "valid_to": null,        // null = 現在有効。改定時は必ず前日で閉じる
              "source": "URL",         // 出典（公式 or impress.co.jp系のみ）
              "note": ""               // 備考。「編集部確認」を含むとニュース欄の対象外になる
            }
          ]
        }
      ]
    }
  ]
}
```

### 重要な不変条件

- **`id`は変更禁止**（記事からの`#直リンク`・シミュレーターのlocalStorage記憶が壊れる）。名称変更は`name`のみ変え、旧名は`description`に残す（検索が説明文にもヒットする）
- **価格改定時は旧エントリの`valid_to`を改定前日で閉じてから**新エントリを追加（edit.htmlの「💴 価格改定を記録」がこれを自動化）
- **サービス/プランの削除は原則しない**。終了は`ended`で表現し履歴を保持する
- 表示順 = 配列順（カテゴリもサービスもプランも）

### noteの規約

- `編集部確認` を含む → 「収録時点の確認価格・正式な改定日ではない」の意。改定ニュース欄の生成対象から除外される
- 出典に明記されていない数字（自前の税込計算・為替換算など）をnoteに書かない

## 3. 公開ページ（index.html）の主要ロジック

すべて`<script>`内のVanilla JS。関数名で検索可能。

| 機能 | 実装 | 仕様 |
|---|---|---|
| 現在価格 | `getCurrentPrice()` | `valid_to===null`のうち`valid_from`最新（閉じ忘れに耐性） |
| 値上げ/値下げバッジ | `recentChange()` | 直近**12カ月**、同一通貨・同一billing間の比較のみ |
| 改定ニュース欄 | `buildNews()` | 直近**6カ月**・最大8件。改定/新プラン/通貨変更/終了を自動分類。「編集部確認」除外。既読管理は`localStorage: spw_news_seen` |
| 価格推移グラフ | `buildPriceChart()` | 階段状SVG。現在通貨と同じエントリのみ描画（ドル建て→円建て移行は対象外） |
| 合計シミュレーター | `sim*` 一式 | モード式。選択は`localStorage: spw_sim`。ended系は対象外。年払いは月額換算合算、USDは別建て表示 |
| 詳細モーダル | `openModal()/closeModal()` | History APIと連動：`#サービスid`で直リンク可、スマホの「戻る」で閉じる |
| 説明の折りたたみ | `spw_about_seen` | 初回訪問のみ自動展開 |
| USD→JPY換算 | `USD_TO_JPY`定数 | **価格順ソートの内部計算専用**。画面には一切表示しない方針 |

localStorageキー: `spw_sim` / `spw_news_seen` / `spw_about_seen`

## 4. 編集ツール（edit.html）

- 起動: `powershell -ExecutionPolicy Bypass -File serve.ps1` → `http://localhost:3000/edit.html`
- `#サービスid` でそのサービスの編集を直接開ける
- 「⬆ 保存して反映」→ `POST /save` → serve.ps1がdb.jsonへ書き込み（`last_updated`も自動更新）
- 「💴 価格改定を記録」: 旧価格クローズ＋新エントリ追加＋通貨等の引き継ぎを一括実行
- 公開はgit push（Actionsが自動デプロイ、1〜2分）

## 5. デプロイ

- GitHub Actions（`.github/workflows/pages.yml`、actions/deploy-pages）
- **branch方式（Deploy from a branch）は使わない**：「Deployment failed, try again later.」が頻発したため切替済み
- Actions方式でも同エラーが稀に出る。**空コミットのpushで再トリガー**すれば通る（ワークフローへの自動リトライは負荷配慮で不採用）

## 6. 開発時の注意（Windows環境）

- db.jsonをスクリプトで一括編集する場合、**.ps1はUTF-8 BOM付きで保存**しないとPowerShell 5.1が日本語リテラルを壊す。書き込みはBOMなしUTF-8。編集後は`ConvertFrom-Json`で必ず検証
- `ConvertFrom-Json | ConvertTo-Json`の往復は**単一要素配列を潰す**（`["video"]`→`"video"`）ため禁止。文字列置換で編集する
- 表示テキストのカッコは半角`()`に統一

## 7. 編集ルール（要旨）

詳細は[CLAUDE.md](CLAUDE.md)。

1. 出典の優先度: ①サービス公式 ②Impress Watch ③その他Watchシリーズ（impress.co.jpドメイン）。他媒体は使わない
2. 出典に明記されていない数字を書かない
3. ドル建ては「xx USドル(税別)」のまま。円換算表示はしない（為替管理を避ける）

## 8. 既知の制限・本番組み込み時の検討事項

- **複数カテゴリのUI編集未対応**: `categories`配列は複数持てるが、edit.htmlのUIは単一選択（複数化はJSON直接編集）
- **編集の同時実行に弱い**: db.jsonは1行ファイルのため、並行編集はgitレベルで必ず衝突する。本番では編集をCMS/DBに載せ替える想定
- **認証なし**: 公開URLは誰でも閲覧可。限定公開が必要ならCloudflare Pages+Access等（検討済み・現状は不採用）
- **アフィリエイトのPR表記**: ステマ規制対応で「※アフィリエイト広告（PR）を含みます」を自動付与している。文言・位置は法務確認を推奨
- **編集部確認の残項目**: [docs/EDITORIAL_CHECK.md](docs/EDITORIAL_CHECK.md) 参照（12件）
