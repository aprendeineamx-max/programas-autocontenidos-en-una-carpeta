Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $PSCommandPath
Set-Location $here

param(
    [string]$CatalogPath = 'portable-apps.json',
    [string]$AppName,
    [switch]$Launch,
    [switch]$SkipMissing
)

. "$here\portable.ps1"
Initialize-PortableRoot | Out-Null

function Resolve-RepoPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    $full = Join-Path $here $Path
    if (Test-Path -LiteralPath $full) { return (Resolve-Path -LiteralPath $full).Path }
    return $full
}

if (-not (Test-Path -LiteralPath $CatalogPath)) {
    throw "No se encuentra el catálogo en $CatalogPath"
}

$apps = Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json
if ($AppName) {
    $apps = $apps | Where-Object { $_.name -eq $AppName }
    if (-not $apps) { throw "App '$AppName' no se encuentra en el catálogo." }
}

foreach ($app in $apps) {
    Write-Host "=== [$($app.name)] Rehidratando ===" -ForegroundColor Cyan
    $installerPath = Resolve-RepoPath $app.installer
    if (-not $installerPath -or -not (Test-Path -LiteralPath $installerPath)) {
        if ($SkipMissing) {
            Write-Warning "Installer no encontrado para $($app.name): $installerPath"
            continue
        }
        throw "Installer no encontrado para $($app.name): $installerPath"
    }
    $args = $app.installerArgs
    Install-PortableApp -AppName $app.name -InstallerPath $installerPath -InstallerArgs $args
    Write-Host "Instalación completada para $($app.name)" -ForegroundColor Green

    if ($Launch) {
        $exe = Resolve-RepoPath $app.executable
        if (-not (Test-Path -LiteralPath $exe)) {
            Write-Warning "No se encontró ejecutable para $($app.name): $exe"
        } else {
            Start-PortableApp -AppName $app.name -Executable $exe -Arguments $app.launchArgs -WorkingDirectory (Resolve-RepoPath $app.workingDir)
            Write-Host "Lanzado $($app.name)" -ForegroundColor Green
        }
    }
    Write-Host ""
}

Write-Host "Proceso de rehidratación finalizado." -ForegroundColor Green
