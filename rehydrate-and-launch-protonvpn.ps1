Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $PSCommandPath
Set-Location $here

function Run-Install {
    $installerPs1 = Join-Path $here 'install-protonvpn-portable.ps1'
    if (-not (Test-Path -LiteralPath $installerPs1)) {
        throw "No se encuentra install-protonvpn-portable.ps1"
    }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$installerPs1`""
    $psi.UseShellExecute = $true
    $psi.Verb = 'runas'  # solicitar admin para registrar servicios/drivers
    $p = [System.Diagnostics.Process]::Start($psi)
    $p.WaitForExit()
    if ($p.ExitCode -ne 0) {
        throw "Instalador devolvió código $($p.ExitCode)"
    }
}

function Run-Launch {
    $launcherPs1 = Join-Path $here 'launch-protonvpn-portable.ps1'
    if (-not (Test-Path -LiteralPath $launcherPs1)) {
        throw "No se encuentra launch-protonvpn-portable.ps1"
    }
    & powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File $launcherPs1
}

Write-Host "Reinstalando servicios/controladores ProtonVPN (admin requerido)..." -ForegroundColor Cyan
Run-Install
Write-Host "Lanzando ProtonVPN portable..." -ForegroundColor Cyan
Run-Launch
Write-Host "Listo." -ForegroundColor Green
