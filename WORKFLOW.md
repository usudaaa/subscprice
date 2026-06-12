# データ反映ワークフロー

`edit.html` でデータを編集してから `index.html` に反映するまでの 3 通りの方法。

---

## 方法A：Claudeに丸投げ（推奨・一番簡単）

1. **`edit.html`** をブラウザで開いて編集
2. 上部「**全データをコピー／エクスポート**」 → 「**📋 クリップボードにコピー**」
3. Claude Code のチャットに **そのまま貼り付けて** こう書く:

> ```
> 以下のJSONで index.html を更新してください
> [貼り付け]
> ```

Claude が `index.html` の `const DB = {...};` を自動で書き換えます。

---

## 方法B：PowerShell スクリプトで反映（オフライン可）

1. `edit.html` で編集 → 「**💾 export.json に保存**」をクリック
2. ダウンロードされた `export.json` をプロジェクトルートに置く
3. PowerShell で：

```powershell
cd C:\Users\usuda\Dropbox\WIP2\IPW\ClaudeCode\Subscprice
powershell -ExecutionPolicy Bypass -File apply-db.ps1
```

`apply-db.ps1` が `index.html` の DB ブロックを置き換え、バックアップ（`index.html.bak_yyyyMMdd_HHmmss`）も作成します。

### 引数指定（別パス・別ファイルの場合）

```powershell
powershell -ExecutionPolicy Bypass -File apply-db.ps1 -JsonPath "data\export.json" -IndexPath "index.html"
```

---

## 方法C：手動コピペ（昔ながらの方法）

1. `edit.html` で「全データをコピー／エクスポート」 → 「📋 クリップボードにコピー」
2. `index.html` を開き、`const DB = ` から `};` までを探す（行 163 付近）
3. 全部を選択して貼り付け
4. 保存 → ブラウザリロード

---

## なぜ自動反映できないのか（DAZN問題の原因）

`edit.html` はブラウザ上で動く HTML/JS なので、**セキュリティ制約により自分自身や `index.html` のファイルを直接書き換えられない**。「保存」ボタンはメモリ内の `DB` オブジェクトを更新するだけ。

そのため必ず「**エクスポート → 反映**」の 2 ステップが必要になります。方法A/Bはこの2ステップ目を自動化したものです。

---

## トラブルシューティング

| 症状 | 原因・対処 |
|---|---|
| 反映されない | ブラウザのキャッシュ。**Ctrl+F5** でハードリロード |
| `apply-db.ps1` でエラー | `export.json` の文字コードが UTF-8 か確認。BOM 付きでも動作するはず |
| バックアップが溜まる | `index.html.bak_*` は自由に削除して OK |
| 編集して保存したのに消えた | `edit.html` をリロードするとメモリ内データが失われる。必ずエクスポートしてから閉じる |
