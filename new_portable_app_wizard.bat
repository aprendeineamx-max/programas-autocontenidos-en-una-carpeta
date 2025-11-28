@echo off
setlocal
pushd %~dp0
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0new-portable-app.ps1"
popd
endlocal
