# setup_usb.ps1  —  Run on Windows before connecting the Android app
# Usage: Right-click → "Run with PowerShell"

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "  MOBILE GAMEPAD — USB SETUP" -ForegroundColor Cyan
Write-Host "  =============================" -ForegroundColor Cyan
Write-Host ""

# ── 1. Check ADB ──────────────────────────────────────────────────────────────
try {
    $adbOut = & adb version 2>&1 | Select-Object -First 1
    Write-Host "  [OK] ADB found: $adbOut" -ForegroundColor Green
} catch {
    Write-Host "  [ERR] ADB not found in PATH." -ForegroundColor Red
    Write-Host "        Download Android Platform Tools from:" -ForegroundColor Yellow
    Write-Host "        https://developer.android.com/studio/releases/platform-tools" -ForegroundColor Yellow
    Read-Host "  Press Enter to exit"
    exit 1
}

# ── 2. Check ViGEmBus ─────────────────────────────────────────────────────────
$vigem = Get-PnpDevice | Where-Object { $_.FriendlyName -like "*ViGEm*" } -ErrorAction SilentlyContinue
if ($vigem) {
    Write-Host "  [OK] ViGEmBus driver detected" -ForegroundColor Green
} else {
    Write-Host "  [WARN] ViGEmBus not detected." -ForegroundColor Yellow
    Write-Host "         Download from: https://github.com/nefarius/ViGEmBus/releases" -ForegroundColor Yellow
    Write-Host "         Install it, then re-run this script." -ForegroundColor Yellow
}

# ── 3. Check connected devices ────────────────────────────────────────────────
Write-Host ""
Write-Host "  Connected ADB devices:" -ForegroundColor Cyan
$devices = & adb devices 2>&1
Write-Host $devices

$deviceCount = ($devices | Select-String "device$").Count
if ($deviceCount -eq 0) {
    Write-Host ""
    Write-Host "  [ERR] No device found. Check USB cable and enable USB Debugging." -ForegroundColor Red
    Read-Host "  Press Enter to exit"
    exit 1
}

# ── 4. Set up reverse tunnel ──────────────────────────────────────────────────
Write-Host ""
Write-Host "  Setting up reverse TCP tunnel …" -ForegroundColor Cyan
& adb reverse tcp:5000 tcp:5000
Write-Host "  [OK] Tunnel ready: Android localhost:5000 → This PC:5000" -ForegroundColor Green

# ── 5. Check for server exe ───────────────────────────────────────────────────
Write-Host ""
$exePath = Join-Path $PSScriptRoot "rust_backend\target\release\gamepad_server.exe"
if (Test-Path $exePath) {
    Write-Host "  [OK] gamepad_server.exe found at: $exePath" -ForegroundColor Green
    $launch = Read-Host "  Launch server now? (y/n)"
    if ($launch -eq 'y') {
        Start-Process $exePath -NoNewWindow
        Write-Host "  [OK] Server launched" -ForegroundColor Green
    }
} else {
    Write-Host "  [INFO] gamepad_server.exe not found." -ForegroundColor Yellow
    Write-Host "         Build it with: cd rust_backend && cargo build --release" -ForegroundColor Yellow
    Write-Host "         Or launch via the Windows Flutter app." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  All done! Open the app on Android and tap CONNECT." -ForegroundColor Cyan
Write-Host ""
Read-Host "  Press Enter to close"
