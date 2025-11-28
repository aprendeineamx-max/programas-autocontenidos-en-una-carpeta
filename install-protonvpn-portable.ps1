Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $PSCommandPath
Set-Location $here

function Ensure-Elevated {
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($id)
    if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "Reintentando como administrador..."
        $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        Start-Process -FilePath "powershell" -ArgumentList $args -Verb RunAs
        exit
    }
}

Ensure-Elevated

. "$here\portable.ps1"
Initialize-PortableRoot | Out-Null

$installerDefault = Join-Path $here 'installers\ProtonVPN_v4.3.7_x64.exe'
param(
    [string]$InstallerPath = $installerDefault
)

if (-not (Test-Path -LiteralPath $InstallerPath)) {
    throw "No se encontró el instalador en $InstallerPath. Copia ProtonVPN_v4.3.7_x64.exe a installers/ o pasa -InstallerPath."
}

Write-Host "Instalando ProtonVPN portable en: $Script:PortableRoot" -ForegroundColor Cyan
Install-PortableApp -AppName 'ProtonVPN' -InstallerPath $InstallerPath -InstallerArgs '/DIR="{BIN}" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART'
Write-Host "Listo. Binarios en apps\\ProtonVPN\\bin, datos en data\\ProtonVPN." -ForegroundColor Green
