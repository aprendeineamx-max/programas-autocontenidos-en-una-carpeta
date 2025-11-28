Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $PSCommandPath
Set-Location $here

. "$here\portable.ps1"
$root = Initialize-PortableRoot

param(
    [Parameter(Mandatory = $true)][ValidateSet('backup','restore')][string]$Mode,
    [string]$AppName = 'ProtonVPN',
    [Parameter(Mandatory = $true)][string]$ArchivePath
)

$app = Get-PortablePaths -AppName $AppName

if ($Mode -eq 'backup') {
    if (-not (Test-Path -LiteralPath $app.DataRoot)) {
        throw "No existe data para '$AppName' en $($app.DataRoot)"
    }
    $tmpZip = Resolve-Path -LiteralPath (New-Item -ItemType File -Path $ArchivePath -Force)
    if (Test-Path -LiteralPath $tmpZip) {
        Remove-Item -LiteralPath $tmpZip -Force
    }
    Compress-Archive -Path (Join-Path $app.DataRoot '*') -DestinationPath $ArchivePath
    Write-Host "Backup listo: $ArchivePath" -ForegroundColor Green
}

if ($Mode -eq 'restore') {
    if (-not (Test-Path -LiteralPath $ArchivePath)) {
        throw "No se encuentra el backup en $ArchivePath"
    }
    if (-not (Test-Path -LiteralPath $app.DataRoot)) {
        New-Item -ItemType Directory -Path $app.DataRoot | Out-Null
    }
    Expand-Archive -Path $ArchivePath -DestinationPath $app.DataRoot -Force
    Write-Host "Restaurado en: $($app.DataRoot)" -ForegroundColor Green
}
