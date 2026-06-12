# apply-db.ps1
# Usage: powershell -ExecutionPolicy Bypass -File apply-db.ps1 [-JsonPath export.json] [-IndexPath index.html]
param(
    [string]$JsonPath = "export.json",
    [string]$IndexPath = "index.html"
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
$jsonFull = Join-Path $scriptDir $JsonPath
$indexFull = Join-Path $scriptDir $IndexPath

if (-not (Test-Path $jsonFull)) {
    Write-Host "[ERROR] JSON file not found: $jsonFull" -ForegroundColor Red
    exit 1
}

$jsonRaw = [System.IO.File]::ReadAllText($jsonFull, [System.Text.Encoding]::UTF8)
$jsonRaw = $jsonRaw.Trim()
if ($jsonRaw.StartsWith('const DB')) {
    $jsonRaw = $jsonRaw -replace '^const\s+DB\s*=\s*', ''
    $jsonRaw = $jsonRaw.TrimEnd(';').Trim()
}

try {
    $obj = $jsonRaw | ConvertFrom-Json
} catch {
    Write-Host "[ERROR] Invalid JSON: $_" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $indexFull)) {
    Write-Host "[ERROR] index.html not found: $indexFull" -ForegroundColor Red
    exit 1
}
$indexContent = [System.IO.File]::ReadAllText($indexFull, [System.Text.Encoding]::UTF8)

$startMarker = 'const DB = '
$startIdx = $indexContent.IndexOf($startMarker)
if ($startIdx -lt 0) {
    Write-Host "[ERROR] 'const DB = ' not found in index.html" -ForegroundColor Red
    exit 1
}

$braceStart = $indexContent.IndexOf('{', $startIdx)
$depth = 0
$inString = $false
$escape = $false
$braceEnd = -1
for ($i = $braceStart; $i -lt $indexContent.Length; $i++) {
    $ch = $indexContent[$i]
    if ($escape) { $escape = $false; continue }
    if ($ch -eq '\') { $escape = $true; continue }
    if ($ch -eq '"') { $inString = -not $inString; continue }
    if ($inString) { continue }
    if ($ch -eq '{') { $depth++ }
    elseif ($ch -eq '}') {
        $depth--
        if ($depth -eq 0) { $braceEnd = $i; break }
    }
}
if ($braceEnd -lt 0) {
    Write-Host "[ERROR] DB block end not found" -ForegroundColor Red
    exit 1
}

$semiIdx = $indexContent.IndexOf(';', $braceEnd)
if ($semiIdx -lt 0) { $semiIdx = $braceEnd }

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupPath = $indexFull + '.bak_' + $stamp
[System.IO.File]::Copy($indexFull, $backupPath, $true)
Write-Host ("[BACKUP] " + (Split-Path $backupPath -Leaf)) -ForegroundColor Cyan

$before = $indexContent.Substring(0, $startIdx + $startMarker.Length)
$after = $indexContent.Substring($semiIdx + 1)
$newContent = $before + $jsonRaw + ';' + $after

[System.IO.File]::WriteAllText($indexFull, $newContent, (New-Object System.Text.UTF8Encoding $false))

$catCount = $obj.categories.Count
$svcCount = $obj.services.Count
$planCount = ($obj.services | ForEach-Object { $_.plans.Count } | Measure-Object -Sum).Sum

Write-Host ""
Write-Host "[OK] index.html updated" -ForegroundColor Green
Write-Host ("  categories: " + $catCount)
Write-Host ("  services  : " + $svcCount)
Write-Host ("  plans     : " + $planCount)
Write-Host ""
Write-Host "Reload the browser (Ctrl+F5) to see changes."
