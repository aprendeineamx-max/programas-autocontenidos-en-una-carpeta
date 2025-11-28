Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $PSCommandPath
Set-Location $here

. "$here\portable.ps1"
$paths = Initialize-PortableRoot

param(
    [string]$AppName,
    [string]$CatalogPath = 'portable-apps.json'
)

$catalog = @()
if (Test-Path -LiteralPath $CatalogPath) {
    $raw = Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json
    if ($raw) { $catalog = @($raw) }
}
if ($AppName) {
    $catalog = $catalog | Where-Object { $_.name -eq $AppName }
}
if (-not $catalog) {
    Write-Warning "No hay apps en el catálogo (o no coincide AppName)."
    $catalog = @()
}

function Test-InRepo {
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )
        $norm = (Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue)?.Path
        if (-not $norm) { return @{ Path = $Path; InRepo = $false; Reason = 'No existe' } }
        $inRepo = $norm.StartsWith($paths.Root, [System.StringComparison]::OrdinalIgnoreCase)
        return @{ Path = $norm; InRepo = $inRepo; Reason = $(if ($inRepo) { '' } else { "Fuera del repo ($($paths.Root))" }) }
    }

$envChecks = @('APPDATA','LOCALAPPDATA','PROGRAMDATA','TEMP','TMP','USERPROFILE') | ForEach-Object {
    $val = [Environment]::GetEnvironmentVariable($_,'Process')
    Test-InRepo -Path $val
} | ForEach-Object { [pscustomobject]$_ }

Write-Host "=== Entorno portable esperado ===" -ForegroundColor Cyan
Write-Host ("Portable root: {0}" -f $paths.Root)
Write-Host ""

Write-Host "=== Variables de entorno ===" -ForegroundColor Cyan
$envChecks | Format-Table -AutoSize
Write-Host ""

foreach ($app in $catalog) {
    Write-Host "=== App: $($app.name) ===" -ForegroundColor Cyan
    $pathsApp = Get-PortablePaths -AppName $app.name

    $expected = @(
        $pathsApp.AppDataRoaming,
        $pathsApp.AppDataLocal,
        $pathsApp.ProgramData,
        $pathsApp.UserProfile,
        $pathsApp.Temp
    )
    if ($app.dataPaths) {
        $expected += $app.dataPaths | ForEach-Object {
            Join-Path $paths.Root $_
        }
    }
    $expected = $expected | Sort-Object -Unique
    $expectedStatus = $expected | ForEach-Object { [pscustomobject](Test-InRepo -Path $_) }
    $expectedStatus | Format-Table -AutoSize

    $leaks = @()
    if ($app.knownExternalPaths) {
        foreach ($p in $app.knownExternalPaths) {
            $expanded = $p
            foreach ($kv in @{'%APPDATA%'=$env:APPDATA; '%LOCALAPPDATA%'=$env:LOCALAPPDATA; '%PROGRAMDATA%'=$env:PROGRAMDATA}) {
                $expanded = $expanded.Replace($kv.Keys, $kv.Values)
            }
            $found = Get-ChildItem -Path $expanded -ErrorAction SilentlyContinue -Force
            if ($found) {
                $found | ForEach-Object { $leaks += $_.FullName }
            }
        }
    }
    if ($leaks.Count -gt 0) {
        Write-Warning "Fugas detectadas fuera del repo:"
        $leaks | Sort-Object -Unique | ForEach-Object { Write-Host " - $_" }
    } else {
        Write-Host "No se detectaron fugas conocidas para $($app.name)." -ForegroundColor Green
    }
    if ($app.notes) {
        Write-Host "Notas: $($app.notes)" -ForegroundColor Yellow
    }
    Write-Host ""
}
