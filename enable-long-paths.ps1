Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Debe ejecutarse como administrador para modificar HKLM.
$identity   = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal  = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Reintentando como administrador..." -ForegroundColor Yellow
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell -Verb RunAs -ArgumentList $args
    exit
}

$key = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
Set-ItemProperty -Path $key -Name LongPathsEnabled -Type DWord -Value 1
Write-Host "LongPathsEnabled habilitado. Reinicia sesión o el equipo para que surta efecto." -ForegroundColor Green
