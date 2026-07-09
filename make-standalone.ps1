# 社内配布用スタンドアロンHTML生成スクリプト
# index.html のfetch起動部を、db.jsonを埋め込んだ直接起動に置き換えた
# 単体ファイル subscprice_snapshot.html を生成する（サーバー不要・ダブルクリックで開ける）
# 使い方: powershell -ExecutionPolicy Bypass -File make-standalone.ps1

$root = $PSScriptRoot
$html = [System.IO.File]::ReadAllText((Join-Path $root 'index.html'), [System.Text.Encoding]::UTF8)
$db   = [System.IO.File]::ReadAllText((Join-Path $root 'data\db.json'), [System.Text.Encoding]::UTF8).Trim()

$marker = '// ===== 起動：データ読み込み ====='
$idx = $html.IndexOf($marker)
if ($idx -lt 0) { Write-Error "起動マーカーが見つかりません"; exit 1 }
$catchIdx = $html.IndexOf('.catch(', $idx)
$endIdx = $html.IndexOf('});', $catchIdx) + 3

$boot = @"
// ===== 起動（スタンドアロン版：データ内蔵・サーバー不要） =====
DB = $db;
(function(){
    categoryMap = Object.fromEntries(DB.categories.map(c=>[c.id,c.name]));
    if(DB.last_updated){
      const [y,m,d] = DB.last_updated.split('-').map(Number);
      document.getElementById('pageUpdated').textContent = ``最終更新：`${y}年`${m}月`${d}日（配布用スナップショット）``;
    }
    DB.services.forEach(svc=>svc.plans.forEach(plan=>{ simPlanMap[plan.id] = {svc, plan}; }));
    try{ simLoad(); }catch(e){}
    buildCatNav();
    buildNews();
    renderList();
    try{ setSimMode(sim.mode); }catch(e){}
    const hashId = decodeURIComponent(location.hash.slice(1));
    if(hashId && DB.services.some(s=>s.id===hashId)){
      try{ history.replaceState({modal:hashId, deep:true}, '', '#'+encodeURIComponent(hashId)); }catch(e){}
      openModal(hashId, true);
    }
})();
"@

$out = $html.Substring(0, $idx) + $boot + $html.Substring($endIdx)
$out = $out.Replace('<title>サブスク料金ナビ — Impress Watch</title>', '<title>サブスク料金ナビ（社内確認用） — Impress Watch</title>')

$outPath = Join-Path $root 'subscprice_snapshot.html'
[System.IO.File]::WriteAllText($outPath, $out, (New-Object System.Text.UTF8Encoding $false))
Write-Host ("OK: " + $outPath + " (" + (Get-Item $outPath).Length + " bytes)")
