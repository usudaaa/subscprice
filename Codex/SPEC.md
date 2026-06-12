# 仕様書 — サブスクリプション価格ウォッチ

## 1. プロジェクト概要

- **名称**: サブスクリプション価格ウォッチ
- **掲載先想定**: Impress Watch（https://www.watch.impress.co.jp/）の特集記事
- **目的**: 主要なテック系サブスクリプション（Apple One、Google One、Netflix、Spotify、Claude、ChatGPT 等）の現在価格を一覧で見せ、過去の価格改定履歴も追える
- **更新頻度**: 数年に 1 回程度（低頻度）
- **読者**: 一般のテック系記事読者

## 2. 技術要件

| 項目 | 内容 |
|---|---|
| 言語 | HTML5 / CSS3 / Vanilla JavaScript（ES6+） |
| フレームワーク | 使用しない |
| ビルドツール | 使用しない |
| 動作環境 | モダンブラウザ（Chrome, Safari, Firefox, Edge 最新版） |
| ファイル配信 | 静的（`file://` で開いても動作すること） |
| データ保持 | HTML 内インライン JSON（`fetch()` 禁止） |

## 3. ファイル構成

```
プロジェクトルート/
├── index.html   ← 公開ページ
├── edit.html    ← 編集ツール
└── data.json    ← 元データ（HTML への埋め込み用、リファレンス）
```

## 4. データスキーマ

```javascript
DB = {
  categories: [
    { id: "tech-bundle", name: "テクノロジー総合" },
    // ...
  ],
  services: [
    {
      id: "apple-one",
      name: "Apple One",
      provider: "Apple",
      category: "tech-bundle",
      url: "https://www.apple.com/jp/apple-one/",
      url_label: "Apple One詳細ページ",
      description: "サービス説明（モーダル内で表示する 1〜3 文）",
      plans: [
        {
          id: "apple-one-individual",
          name: "個人",
          description: "50GBストレージ込み",
          price_history: [
            {
              amount: 1100,
              currency: "JPY",          // "JPY" or "USD"
              billing: "monthly",       // "monthly" or "annual"
              tax_included: true,       // 円は基本 true、USD は false
              valid_from: "2020-11-01", // 適用開始日（YYYY-MM-DD）
              valid_to: "2023-01-31",   // 適用終了日。null = 現在価格
              source: "https://www.apple.com/jp/apple-one/",
              note: "サービス開始時"
            },
            { /* ... 最新の価格 ... valid_to: null */ }
          ]
        }
      ]
    }
  ]
}
```

### 重要なルール

- `valid_to: null` の price_history エントリが **「現在価格」**
- 価格改定は履歴を **追加** する形（古い行は消さない）
- `currency: "USD"` のものは USD 表示・税別前提
- `billing: "annual"` は年額表示（Nintendo Switch Online など）

## 5. カテゴリ

順序は以下のとおり：

1. `tech-bundle` — テクノロジー総合
2. `storage` — ストレージ
3. `ai` — AI
4. `business` — ビジネス
5. `music` — 音楽
6. `video` — 動画
7. `game` — ゲーム・その他
8. `japan-tech` — 日本のテック系

## 6. index.html の機能

### 6.1 ページ構造（上から順）

1. **サイトヘッダー**: 「Impress Watch」ロゴ風＋パンくず
2. **ページヘッダー**: タイトル「サブスクリプション価格ウォッチ」＋リード文
3. **カテゴリナビ**: 「すべて」＋8 カテゴリの切り替えボタン（横並びタブ）
4. **サービス一覧**: カテゴリごとにテーブル表示
5. **モーダル**（クリックで開く）

### 6.2 サービス一覧テーブル

3 カラム構成：

| 列 | 内容 | 幅 |
|---|---|---|
| サービス名 | サービス名（太字）＋提供元（小） | 22% |
| プラン・価格 | プラン名 / 現在価格 / 単位 / 改定履歴バッジ（過去価格があれば） | 60% |
| （ボタン） | 「詳細・推移 ›」ボタン | 18% |

- 価格表示例: `個人　1,200円/月`、`Plus　20 USドル（税別）/月`、`年間プラン　6,900円/年`
- 改定履歴があるプランには `改定履歴あり` バッジを表示
- カテゴリナビをクリックすると該当カテゴリのみ表示（`renderList(filterCat)` で再描画）

### 6.3 モーダル

「詳細・推移 ›」をクリックで開く。中身：

1. **ヘッダー**: サービス名＋提供元・カテゴリ＋閉じるボタン
2. **サービス概要**: `description` テキスト
3. **公式サイトリンク**: `url` を新規タブで開く
4. **価格一覧・改定履歴**: プランごとに表

#### 価格履歴テーブル（プランごと）

| 適用期間 | 価格 | 備考 |
|---|---|---|
| 2023年2月 〜 現在 | 1,200円/月 [現在] | 価格改定（出典リンク） |
| 2020年11月 〜 2023年1月 | 1,100円/月 [値下げ or 値上げバッジ] | サービス開始時 |

- **「現在」バッジ**: `valid_to: null` の行
- **「値上げ／値下げ」バッジ**: 前後比較で自動判定
- **適用期間表示**: `YYYY年M月` 形式（日付は出さない）
- **閉じる方法**: ✕ボタン / 背景クリック / Escape キー

## 7. edit.html の機能

### 7.1 レイアウト

- 上部: 固定ツールバー（「全データをコピー／エクスポート」ボタン等）
- 左サイドバー（260px）: カテゴリ別サービス一覧 + 検索フィルター + 「+ 新規サービスを追加」ボタン
- メイン: 編集フォーム

### 7.2 メイン編集フォーム

- **基本情報カード**: サービスID / 名称 / 提供元 / カテゴリ / URL / URL ラベル / 概要
- **プランカード（プランごとに 1 つ）**: プランID / プラン名 / プラン説明
  - **価格履歴エントリ（履歴ごとに 1 つ）**: 金額 / 通貨 / 課金サイクル / 税込・税別 / 開始日 / 終了日 / 出典 / メモ
- **アクション**: 「このサービスを保存」「価格履歴を追加」「プランを追加」「サービスを削除」

### 7.3 価格履歴の追加

「価格履歴を追加」ボタン押下時の挙動：

1. 現在価格のエントリ（`valid_to: null`）の `valid_to` を **昨日の日付** に自動セット
2. 新しいエントリを `valid_from: 今日`, `valid_to: null` で追加（他のフィールドは現在価格をコピー）

### 7.4 エクスポート

「全データをコピー／エクスポート」ボタン → モーダル：

- `<textarea>` に `const DB = ` + `JSON.stringify(DB, null, 2)` + `;` を表示
- 「📋 クリップボードにコピー」ボタン
- 「💾 export.json に保存」ボタン（JSON ファイルをダウンロード）

このエクスポートを index.html の `const DB = {...};` 行に貼り戻すと反映される。

## 8. ヘルパー関数（参考）

```javascript
function getCurrentPrice(plan) {
  return plan.price_history.find(p => p.valid_to === null);
}

function fmtAmount(p) {
  if (p.currency === 'JPY') return p.amount.toLocaleString() + '円';
  return p.amount + ' USドル（税別）';
}

function fmtBilling(b) {
  return b === 'monthly' ? '/月' : b === 'annual' ? '/年' : '';
}

function fmtYM(str) {
  if (!str) return '現在';
  const d = new Date(str);
  return d.getFullYear() + '年' + (d.getMonth() + 1) + '月';
}

function hasHistoryEntry(plan) {
  return plan.price_history.some(p => p.valid_to !== null);
}
```

## 9. アクセシビリティ／その他

- 日本語表示前提（`<html lang="ja">`、charset UTF-8）
- フォントは Hiragino Sans / Noto Sans JP / Meiryo のフォールバック
- モーダルは Escape キーで閉じる、フォーカストラップは不要（簡易実装で OK）
- 公式サイトリンクは `target="_blank" rel="noopener"`

## 10. 受け入れ基準

- [ ] `index.html` をダブルクリックでブラウザで開け、全カテゴリ・全サービスが表示される
- [ ] カテゴリタブで絞り込みできる
- [ ] 「詳細・推移」ボタンでモーダルが開く
- [ ] 価格改定履歴のあるサービス（例: Apple One）でモーダル内に複数行の表が出る
- [ ] 「値上げ」「値下げ」バッジが正しく出る
- [ ] `edit.html` で全サービスがサイドバーに出る
- [ ] 価格を編集 → 保存 → エクスポートで反映 JSON が取れる
