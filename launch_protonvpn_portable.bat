@echo off
setlocal
pushd %~dp0
powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch-protonvpn-portable.ps1"
popd
endlocal
