Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $PSCommandPath
Set-Location $here

. "$here\portable.ps1"
$paths = Initialize-PortableRoot

param(
    [string]$AppName = 'ProtonVPN'
)

$app = Get-PortablePaths -AppName $AppName

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

$appFolders = @(
    $app.AppDataRoaming,
    $app.AppDataLocal,
    $app.ProgramData,
    $app.UserProfile,
    $app.Temp
) | ForEach-Object {
    $r = Test-InRepo -Path $_
    [pscustomobject]$r
}

$leaks = @()

function Find-LeaksForApp {
    param(
        [string]$Name
    )
    $userAppData = Join-Path $env:APPDATA $Name
    $userLocal = Join-Path $env:LOCALAPPDATA $Name
    $programData = Join-Path $env:PROGRAMDATA $Name
    foreach ($p in @($userAppData,$userLocal,$programData)) {
        if (Test-Path -LiteralPath $p) {
            $leaks += $p
        }
    }
}

Find-LeaksForApp -Name 'Proton'
Find-LeaksForApp -Name 'ProtonVPN'

Write-Host "=== Entorno portable esperado ===" -ForegroundColor Cyan
Write-Host ("Portable root: {0}" -f $paths.Root)
Write-Host ("App data root: {0}" -f $app.DataRoot)
Write-Host ""

Write-Host "=== Variables de entorno ===" -ForegroundColor Cyan
$envChecks | Format-Table -AutoSize
Write-Host ""

Write-Host "=== Carpetas esperadas del app ===" -ForegroundColor Cyan
$appFolders | Format-Table -AutoSize
Write-Host ""

if ($leaks.Count -gt 0) {
    Write-Warning "Se encontraron datos fuera del repo:"
    $leaks | Sort-Object -Unique | ForEach-Object { Write-Host " - $_" }
    Write-Host "Mueve o borra esos directorios para que el app use solo el sandbox local."
} else {
    Write-Host "No se detectaron datos del app fuera del repo." -ForegroundColor Green
}
