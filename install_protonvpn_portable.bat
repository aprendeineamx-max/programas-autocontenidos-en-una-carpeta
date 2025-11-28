@echo off
setlocal
pushd %~dp0
powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-protonvpn-portable.ps1"
popd
endlocal
