# export-csv.ps1
# Extract DB from index.html and write CSVs per category + an all-in-one CSV.
# Output: data/csv/*.csv (UTF-8 BOM so Excel opens correctly)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$idx = [System.IO.File]::ReadAllText((Join-Path $root 'index.html'), [System.Text.Encoding]::UTF8)
$start = $idx.IndexOf('const DB = ')
$braceStart = $idx.IndexOf('{', $start)
$depth = 0; $inString = $false; $escape = $false; $braceEnd = -1
for ($i = $braceStart; $i -lt $idx.Length; $i++) {
  $ch = $idx[$i]
  if ($escape) { $escape = $false; continue }
  if ($ch -eq '\') { $escape = $true; continue }
  if ($ch -eq '"') { $inString = -not $inString; continue }
  if ($inString) { continue }
  if ($ch -eq '{') { $depth++ } elseif ($ch -eq '}') { $depth--; if ($depth -eq 0) { $braceEnd = $i; break } }
}
$json = $idx.Substring($braceStart, $braceEnd - $braceStart + 1)
$db = $json | ConvertFrom-Json

$outDir = Join-Path $root 'data\csv'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

# CSV header (Japanese, Excel-friendly)
$header = '"カテゴリ","サービスID","サービス名","提供元","公式URL","サービス概要","プランID","プラン名","プラン説明","適用開始","適用終了","金額","通貨","課金","税","出典","備考"'

function Csv-Quote($s) {
  if ($null -eq $s) { return '""' }
  $t = [string]$s
  # Replace newlines with literal space so each row stays single-line
  $t = $t -replace "`r`n", ' ' -replace "`n", ' ' -replace "`r", ' '
  # Escape double quotes by doubling them (RFC 4180)
  $t = $t -replace '"', '""'
  return '"' + $t + '"'
}

$catMap = @{}
foreach ($c in $db.categories) { $catMap[$c.id] = $c.name }

# Per-category CSVs
$catIndex = 1
foreach ($cat in $db.categories) {
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add($header)
  foreach ($svc in ($db.services | Where-Object { $_.category -eq $cat.id })) {
    foreach ($plan in $svc.plans) {
      foreach ($h in $plan.price_history) {
        $row = @(
          (Csv-Quote $cat.name),
          (Csv-Quote $svc.id),
          (Csv-Quote $svc.name),
          (Csv-Quote $svc.provider),
          (Csv-Quote $svc.url),
          (Csv-Quote $svc.description),
          (Csv-Quote $plan.id),
          (Csv-Quote $plan.name),
          (Csv-Quote $plan.description),
          (Csv-Quote $h.valid_from),
          (Csv-Quote $h.valid_to),
          (Csv-Quote $h.amount),
          (Csv-Quote $h.currency),
          (Csv-Quote $h.billing),
          (Csv-Quote $(if ($h.tax_included) { '税込' } else { '税別' })),
          (Csv-Quote $h.source),
          (Csv-Quote $h.note)
        ) -join ','
        $lines.Add($row)
      }
    }
  }
  $fname = '{0:D2}_{1}.csv' -f $catIndex, ($cat.id)
  $outPath = Join-Path $outDir $fname
  # Write with UTF-8 BOM so Excel auto-detects
  $bom = [byte[]](0xEF,0xBB,0xBF)
  $bytes = [System.Text.Encoding]::UTF8.GetBytes(($lines -join "`r`n"))
  [System.IO.File]::WriteAllBytes($outPath, ($bom + $bytes))
  Write-Host ("[OK] " + $fname + "  (" + ($lines.Count - 1) + " rows)")
  $catIndex++
}

# All-in-one CSV
$allLines = New-Object System.Collections.Generic.List[string]
$allLines.Add($header)
foreach ($svc in $db.services) {
  foreach ($plan in $svc.plans) {
    foreach ($h in $plan.price_history) {
      $row = @(
        (Csv-Quote ($catMap[$svc.category])),
        (Csv-Quote $svc.id),
        (Csv-Quote $svc.name),
        (Csv-Quote $svc.provider),
        (Csv-Quote $svc.url),
        (Csv-Quote $svc.description),
        (Csv-Quote $plan.id),
        (Csv-Quote $plan.name),
        (Csv-Quote $plan.description),
        (Csv-Quote $h.valid_from),
        (Csv-Quote $h.valid_to),
        (Csv-Quote $h.amount),
        (Csv-Quote $h.currency),
        (Csv-Quote $h.billing),
        (Csv-Quote $(if ($h.tax_included) { '税込' } else { '税別' })),
        (Csv-Quote $h.source),
        (Csv-Quote $h.note)
      ) -join ','
      $allLines.Add($row)
    }
  }
}
$bom = [byte[]](0xEF,0xBB,0xBF)
$bytes = [System.Text.Encoding]::UTF8.GetBytes(($allLines -join "`r`n"))
[System.IO.File]::WriteAllBytes((Join-Path $outDir 'all.csv'), ($bom + $bytes))
Write-Host ("[OK] all.csv          (" + ($allLines.Count - 1) + " rows)")
Write-Host ""
Write-Host "Output dir: $outDir"
