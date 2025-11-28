@echo off
setlocal
pushd %~dp0
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0enable-long-paths.ps1"
popd
endlocal
