# Zero-dependency local static server for previewing the prototypes at a
# real http://localhost URL instead of file:// (some browser APIs, and the
# game's own fetch-based bits if any get added later, behave differently
# under file://). Honors the same rewrites as vercel.json so local URLs
# match production.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tools/serve-local.ps1 [-Port 5173]

param([int]$Port = 5173)

$root = Split-Path -Parent $PSScriptRoot
if (-not $root) { $root = (Get-Location).Path }
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()

Write-Host "Serving $root"
Write-Host "  http://localhost:$Port/               (index)"
Write-Host "  http://localhost:$Port/flood           (flood-mobile-concept)"
Write-Host "  http://localhost:$Port/nesting-blocks   (nesting-blocks-concept)"
Write-Host "Ctrl+C to stop."

# Same mapping as vercel.json's "rewrites".
$rewrites = @{
  "/flood"           = "/prototypes/flood-mobile-concept/prototype.html"
  "/flood/editor"     = "/prototypes/flood-mobile-concept/editor.html"
  "/nesting-blocks"   = "/prototypes/nesting-blocks-concept/prototype.html"
}

$mime = @{
  ".html"="text/html"; ".htm"="text/html"; ".css"="text/css"; ".js"="application/javascript";
  ".json"="application/json"; ".png"="image/png"; ".jpg"="image/jpeg"; ".jpeg"="image/jpeg";
  ".svg"="image/svg+xml"; ".gif"="image/gif"; ".ico"="image/x-icon"; ".md"="text/plain; charset=utf-8"
}

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $req = $ctx.Request
  $res = $ctx.Response
  try {
    $path = [System.Uri]::UnescapeDataString($req.Url.AbsolutePath)

    if ($rewrites.ContainsKey($path)) {
      $path = $rewrites[$path]
    } elseif ($path -eq "/") {
      $path = "/index.html"
    } elseif (-not [System.IO.Path]::HasExtension($path)) {
      # cleanUrls-style: /prototypes/x/prototype -> prototype.html, if it exists
      $withHtml = Join-Path $root (($path.TrimStart('/')) + ".html")
      if (Test-Path $withHtml -PathType Leaf) { $path = $path + ".html" }
    }

    $fsPath = [System.IO.Path]::GetFullPath((Join-Path $root ($path.TrimStart('/'))))

    if (-not $fsPath.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
      $res.StatusCode = 403
    } elseif (Test-Path $fsPath -PathType Leaf) {
      $ext = [System.IO.Path]::GetExtension($fsPath).ToLower()
      $ct = $mime[$ext]; if (-not $ct) { $ct = "application/octet-stream" }
      $bytes = [System.IO.File]::ReadAllBytes($fsPath)
      $res.ContentType = $ct
      $res.ContentLength64 = $bytes.Length
      $res.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
      $res.StatusCode = 404
      $msg = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found: $path")
      $res.OutputStream.Write($msg, 0, $msg.Length)
    }
  } catch {
    $res.StatusCode = 500
  } finally {
    $res.Close()
  }
}
