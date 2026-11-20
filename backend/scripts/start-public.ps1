# Starts the FamilyGuard server AND a public HTTPS address for it, so phones
# can connect from any network (mobile data, another Wi-Fi) — for testing.
#
#   cd backend
#   npm run public
#
# Uses a Cloudflare "quick tunnel" (no account needed). The address changes
# every time this script starts: enter the new one in both apps
# (Parent: Settings → Server, Child: ⋮ → Server). Keep this window open while
# testing; Ctrl+C stops the server and the tunnel.
#
# Anyone with the address can reach the API (sign-in is still required).
# For a permanent address, deploy the backend or use a named tunnel.

$ErrorActionPreference = 'Stop'
$port = if ($env:PORT) { $env:PORT } else { '4000' }
$backend = Split-Path $PSScriptRoot -Parent
Set-Location $backend

if (-not (Get-Command cloudflared -ErrorAction SilentlyContinue)) {
  Write-Host 'cloudflared is not installed. Install it with:  winget install Cloudflare.cloudflared' -ForegroundColor Red
  exit 1
}
if (-not (Test-Path 'node_modules')) { npm install }

$log = Join-Path $env:TEMP "familyguard-tunnel-$PID.log"
$server = $null
$tunnel = $null
try {
  $env:PORT = $port
  $server = Start-Process node -ArgumentList 'src/index.js' -PassThru -NoNewWindow
  Start-Sleep -Seconds 2

  $tunnel = Start-Process cloudflared `
    -ArgumentList "tunnel --no-autoupdate --url http://localhost:$port" `
    -PassThru -NoNewWindow -RedirectStandardError $log

  $url = $null
  for ($i = 0; $i -lt 60 -and -not $url; $i++) {
    Start-Sleep -Seconds 1
    if (Test-Path $log) {
      $m = Select-String -Path $log -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' | Select-Object -First 1
      if ($m) { $url = $m.Matches[0].Value }
    }
    if ($tunnel.HasExited) { break }
  }

  if (-not $url) {
    Write-Host "Could not get a public address. Tunnel log: $log" -ForegroundColor Red
    exit 1
  }

  Write-Host ''
  Write-Host '=================================================================' -ForegroundColor Cyan
  Write-Host '  FamilyGuard server is reachable from anywhere at:' -ForegroundColor Cyan
  Write-Host ''
  Write-Host "      $url" -ForegroundColor Green
  Write-Host ''
  Write-Host '  Enter this as the Server in the parent and child apps.' -ForegroundColor Cyan
  Write-Host '  Keep this window open. Ctrl+C stops everything.' -ForegroundColor Cyan
  Write-Host '=================================================================' -ForegroundColor Cyan
  Set-Content -Path (Join-Path $backend 'data\public-url.txt') -Value $url -ErrorAction SilentlyContinue

  Wait-Process -Id $tunnel.Id
}
finally {
  foreach ($p in @($tunnel, $server)) {
    if ($p -and -not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
  }
}
