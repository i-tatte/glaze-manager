# Start the Firebase emulators used by the integration tests.
# Uses the demo project only; the real project is never contacted.
# Run from the repository root. Stop with Ctrl+C.
# (ASCII only: Windows PowerShell 5.1 reads BOM-less files as the ANSI code page.)
if (-not (Test-Path 'firebase.emulators.json')) { 'Run this from the repository root.'; exit 2 }
# The storage emulator rejects the PATCH path the Python client uses;
# pyshim/sitecustomize.py reroutes it while running under the emulator.
$env:PYTHONPATH = Join-Path (Get-Location).Path 'tool\emulator\pyshim'
firebase emulators:start --config firebase.emulators.json --only "auth,firestore,storage,functions" --project demo-glaze-manager
