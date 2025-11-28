@echo off
setlocal
pushd %~dp0
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0rehydrate-and-launch-protonvpn.ps1"
popd
endlocal
