# アプリアイコンを候補に切り替えて全OSのアイコンを再生成する。
# 第1ラウンド: a / b / d (Pillow生成)、第2ラウンド: e / f / g / h (SVG→Chrome生成)
# 使い方 (プロジェクトルートで):
#   .\tool\set_app_icon.ps1 e
# 反映にはアプリの再ビルド (flutter run / flutter build) が必要。
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('a', 'b', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r')]
    [string]$Variant
)

$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root "assets\icon\app_icon_$Variant.png"
$target = Join-Path $root "assets\icon\app_icon.png"

if (-not (Test-Path $source)) {
    Write-Error "$source がありません。先に tool\generate_app_icons.py を実行してください。"
    exit 1
}

Copy-Item $source $target -Force
Write-Host "app_icon.png を案 $Variant に切り替えました。flutter_launcher_icons を実行します..."
Push-Location $root
try {
    dart run flutter_launcher_icons
}
finally {
    Pop-Location
}
