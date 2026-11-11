param(
  [Parameter(Mandatory = $true)][string]$Test,
  [string]$Mode = 'online',
  [string[]]$Define = @()
)
# Run one integration test on Windows against the Firebase emulators and print
# only the key lines. Start the emulators first (tool\emulator\start_emulators.ps1).
# Logs, reports and cross-run state go to build\it\ (ignored by git).
# Run from the repository root, e.g.
#   tool\emulator\run_it.ps1 -Test app_flow_test.dart -Mode online
# (ASCII only: Windows PowerShell 5.1 reads BOM-less files as the ANSI code page.)
if (-not (Test-Path 'pubspec.yaml')) { 'Run this from the repository root.'; exit 2 }
$out = Join-Path (Get-Location).Path 'build\it'
New-Item -ItemType Directory -Force $out | Out-Null
$name = [IO.Path]::GetFileNameWithoutExtension($Test)
$log = Join-Path $out "$($name)_$Mode.log"
$defines = @(
  "--dart-define=GM_MODE=$Mode",
  "--dart-define=GM_REPORT_DIR=$out\reports",
  "--dart-define=GM_STATE_DIR=$out\state"
) + ($Define | ForEach-Object { "--dart-define=$_" })
$started = Get-Date
# Go through cmd so that stderr lines stay plain text (PowerShell 5.1 would
# turn them into error records and garble the log).
$quoted = ($defines | ForEach-Object { '"' + $_ + '"' }) -join ' '
cmd /c ('flutter test "integration_test/' + $Test + '" -d windows ' + $quoted + ' > "' + $log + '" 2>&1')
$code = $LASTEXITCODE
"exit: $code  ($([int]((Get-Date) - $started).TotalSeconds)s)" | Out-File $log -Append -Encoding utf8
Get-Content $log -Encoding utf8 |
  Select-String -Pattern '\[gm-it\]|All tests passed|Some tests failed|^exit:|Expected|Actual|Which|Exception|The following|package:glaze_manager|integration_test[\/]|TestFailure|timeout_' |
  Select-Object -Last 70 |
  ForEach-Object { if ($_.Line.Length -gt 420) { $_.Line.Substring(0, 420) + ' ...' } else { $_.Line } }
exit $code
