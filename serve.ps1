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
