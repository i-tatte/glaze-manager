# tool/icons/*.svg を Chrome ヘッドレスで 1024x1024 の PNG にレンダリングし、
# assets/icon/app_icon_<名前>.png として出力する。
# 使い方 (プロジェクトルートで): .\tool\render_app_icons.ps1
$chrome = "C:\Program Files\Google\Chrome\Application\chrome.exe"
if (-not (Test-Path $chrome)) {
    $chrome = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
}
if (-not (Test-Path $chrome)) {
    Write-Error "Chrome が見つかりません"
    exit 1
}

$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root "assets\icon"
New-Item -ItemType Directory -Force $outDir | Out-Null

Get-ChildItem (Join-Path $PSScriptRoot "icons\*.svg") | ForEach-Object {
    $name = $_.BaseName
    $out = Join-Path $outDir "app_icon_$name.png"
    & $chrome --headless=new --disable-gpu --window-size=1024,1024 --screenshot="$out" "file:///$($_.FullName)" 2>$null | Out-Null
    if (Test-Path $out) {
        Write-Host "wrote $out"
    } else {
        Write-Warning "failed: $name"
    }
}
