param(
    [int]$Port = 3000
)

$root = $PSScriptRoot
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving $root on http://localhost:$Port/ (Ctrl+C to stop)"

try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        try {
            $method  = $ctx.Request.HttpMethod
            $urlPath = $ctx.Request.Url.LocalPath

            # POST /save: update index.html DB block from edit.html
            if ($method -eq 'POST' -and $urlPath -eq '/save') {
                try {
                    $reader = New-Object System.IO.StreamReader($ctx.Request.InputStream, [System.Text.Encoding]::UTF8)
                    $body = $reader.ReadToEnd()

                    # Validate JSON (parse only for count reporting)
                    $dbObj = $body | ConvertFrom-Json
                    # Use raw body directly — avoids PowerShell single-element array bug
                    $compact = $body.Trim()

                    $indexPath    = Join-Path $root 'index.html'
                    $indexContent = [System.IO.File]::ReadAllText($indexPath, [System.Text.Encoding]::UTF8)

                    $marker    = 'const DB = '
                    $markerIdx = $indexContent.IndexOf($marker)
                    $bStart    = $indexContent.IndexOf('{', $markerIdx)
                    $depth = 0; $inStr = $false; $esc = $false; $bEnd = -1
                    for ($i = $bStart; $i -lt $indexContent.Length; $i++) {
                        $ch = $indexContent[$i]
                        if ($esc)          { $esc = $false; continue }
                        if ($ch -eq '\')   { $esc = $true;  continue }
                        if ($ch -eq '"')   { $inStr = -not $inStr; continue }
                        if ($inStr)        { continue }
                        if ($ch -eq '{')   { $depth++ }
                        elseif ($ch -eq '}') { $depth--; if ($depth -eq 0) { $bEnd = $i; break } }
                    }
                    $semiIdx = $indexContent.IndexOf(';', $bEnd)

                    $before = $indexContent.Substring(0, $markerIdx + $marker.Length)
                    $after  = $indexContent.Substring($semiIdx + 1)
                    [System.IO.File]::WriteAllText($indexPath, ($before + $compact + ';' + $after), (New-Object System.Text.UTF8Encoding $false))

                    # edit.html も同時更新（ズレ防止）
                    $editPath    = Join-Path $root 'edit.html'
                    $editContent = [System.IO.File]::ReadAllText($editPath, [System.Text.Encoding]::UTF8)
                    $eMarker    = 'let DB = '
                    $eMarkerIdx = $editContent.IndexOf($eMarker)
                    $eBStart    = $editContent.IndexOf('{', $eMarkerIdx)
                    $depth = 0; $inStr = $false; $esc = $false; $eBEnd = -1
                    for ($i = $eBStart; $i -lt $editContent.Length; $i++) {
                        $ch = $editContent[$i]
                        if ($esc)          { $esc = $false; continue }
                        if ($ch -eq '\')   { $esc = $true;  continue }
                        if ($ch -eq '"')   { $inStr = -not $inStr; continue }
                        if ($inStr)        { continue }
                        if ($ch -eq '{')   { $depth++ }
                        elseif ($ch -eq '}') { $depth--; if ($depth -eq 0) { $eBEnd = $i; break } }
                    }
                    $eSemiIdx = $editContent.IndexOf(';', $eBEnd)
                    $eBefore  = $editContent.Substring(0, $eMarkerIdx + $eMarker.Length)
                    $eAfter   = $editContent.Substring($eSemiIdx + 1)
                    [System.IO.File]::WriteAllText($editPath, ($eBefore + $compact + ';' + $eAfter), (New-Object System.Text.UTF8Encoding $false))

                    $svcCount  = $dbObj.services.Count
                    $planCount = ($dbObj.services | ForEach-Object { $_.plans.Count } | Measure-Object -Sum).Sum
                    Write-Host ("[SAVE] index.html + edit.html updated  services=$svcCount  plans=$planCount")
                    $resp = '{"ok":true}'
                } catch {
                    $msg  = ($_.Exception.Message -replace '\\','\\' -replace '"','\"')
                    $resp = "{`"ok`":false,`"error`":`"$msg`"}"
                    Write-Warning "[SAVE ERROR] $_"
                }
                $rb = [System.Text.Encoding]::UTF8.GetBytes($resp)
                $ctx.Response.StatusCode       = 200
                $ctx.Response.ContentType      = 'application/json; charset=utf-8'
                $ctx.Response.Headers.Add('Access-Control-Allow-Origin', '*')
                $ctx.Response.KeepAlive        = $false
                $ctx.Response.ContentLength64  = $rb.LongLength
                $ctx.Response.OutputStream.Write($rb, 0, $rb.Length)
                $ctx.Response.OutputStream.Flush()
                continue
            }

            # OPTIONS preflight (CORS)
            if ($method -eq 'OPTIONS') {
                $ctx.Response.StatusCode = 204
                $ctx.Response.Headers.Add('Access-Control-Allow-Origin', '*')
                $ctx.Response.Headers.Add('Access-Control-Allow-Methods', 'GET,POST,OPTIONS')
                $ctx.Response.Headers.Add('Access-Control-Allow-Headers', 'Content-Type')
                $ctx.Response.KeepAlive = $false
                $ctx.Response.Close()
                continue
            }

            # GET: static file serving
            if ($urlPath -eq '/') { $urlPath = '/index.html' }
            $filePath = Join-Path $root ($urlPath.TrimStart('/') -replace '/', '\')

            if (Test-Path $filePath -PathType Leaf) {
                $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
                $mime = switch ($ext) {
                    '.html' { 'text/html; charset=utf-8' }
                    '.css'  { 'text/css; charset=utf-8' }
                    '.js'   { 'application/javascript; charset=utf-8' }
                    '.json' { 'application/json; charset=utf-8' }
                    '.png'  { 'image/png' }
                    '.jpg'  { 'image/jpeg' }
                    '.svg'  { 'image/svg+xml' }
                    '.ico'  { 'image/x-icon' }
                    default { 'application/octet-stream' }
                }
                $bytes = [System.IO.File]::ReadAllBytes($filePath)
                $ctx.Response.StatusCode  = 200
                $ctx.Response.ContentType = $mime
                $ctx.Response.KeepAlive   = $false
                if ($method -ne 'HEAD') {
                    $ctx.Response.ContentLength64 = $bytes.LongLength
                    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
                    $ctx.Response.OutputStream.Flush()
                }
            } else {
                $body = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found: $urlPath")
                $ctx.Response.StatusCode  = 404
                $ctx.Response.ContentType = 'text/plain; charset=utf-8'
                $ctx.Response.KeepAlive   = $false
                if ($method -ne 'HEAD') {
                    $ctx.Response.ContentLength64 = $body.LongLength
                    $ctx.Response.OutputStream.Write($body, 0, $body.Length)
                    $ctx.Response.OutputStream.Flush()
                }
            }
        } catch {
            Write-Warning "Error handling request: $_"
        } finally {
            try { $ctx.Response.Close() } catch {}
        }
    }
} finally {
    $listener.Stop()
}
