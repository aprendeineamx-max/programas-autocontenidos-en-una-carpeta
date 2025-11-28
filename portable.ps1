# Portable layer para apps "portables" dentro de este repo.
# Redirige APPDATA/LOCALAPPDATA/PROGRAMDATA/USERPROFILE/TEMP a carpetas locales
# solo para el proceso hijo. No toca el sistema ni el registro global.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Rutas base
$Script:PortableRoot = $PSScriptRoot
$Script:PortableApps = Join-Path $PortableRoot 'apps'
$Script:PortableData = Join-Path $PortableRoot 'data'
$Script:PortableTemp = Join-Path $PortableRoot 'temp'

function Initialize-PortableRoot {
    param(
        [string]$Root = $Script:PortableRoot
    )
    $resolved = Resolve-Path -LiteralPath $Root -ErrorAction Stop
    $paths = @{
        Root = $resolved.Path
        Apps = Join-Path $resolved.Path 'apps'
        Data = Join-Path $resolved.Path 'data'
        Temp = Join-Path $resolved.Path 'temp'
    }
    foreach ($p in $paths.Values) {
        if (-not (Test-Path -LiteralPath $p)) {
            New-Item -ItemType Directory -Path $p | Out-Null
        }
    }
    $Script:PortableRoot = $paths.Root
    $Script:PortableApps = $paths.Apps
    $Script:PortableData = $paths.Data
    $Script:PortableTemp = $paths.Temp
    return $paths
}

function Get-PortablePaths {
    param(
        [Parameter(Mandatory = $true)][string]$AppName
    )
    $safe = ($AppName -replace '[^a-zA-Z0-9_.-]', '_')
    $appRoot = Join-Path $Script:PortableApps $safe
    $dataRoot = Join-Path $Script:PortableData $safe
    return @{
        AppName        = $safe
        AppRoot        = $appRoot
        Bin            = Join-Path $appRoot 'bin'
        DataRoot       = $dataRoot
        AppDataRoaming = Join-Path $dataRoot 'AppData\Roaming'
        AppDataLocal   = Join-Path $dataRoot 'AppData\Local'
        ProgramData    = Join-Path $dataRoot 'ProgramData'
        UserProfile    = Join-Path $dataRoot 'UserProfile'
        Temp           = Join-Path $dataRoot 'Temp'
        Cache          = Join-Path $dataRoot 'Cache'
        Logs           = Join-Path $dataRoot 'Logs'
    }
}

function New-PortableApp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$AppName
    )
    $paths = Get-PortablePaths -AppName $AppName
    $toCreate = @(
        $paths.AppRoot,
        $paths.Bin,
        $paths.DataRoot,
        $paths.AppDataRoaming,
        $paths.AppDataLocal,
        $paths.ProgramData,
        $paths.UserProfile,
        $paths.Temp,
        $paths.Cache,
        $paths.Logs
    )
    foreach ($p in $toCreate) {
        if (-not (Test-Path -LiteralPath $p)) {
            New-Item -ItemType Directory -Path $p | Out-Null
        }
    }
    return $paths
}

function Start-PortableApp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$AppName,
        [Parameter(Mandatory = $true)][string]$Executable,
        [string]$Arguments,
        [string]$WorkingDirectory,
        [hashtable]$ExtraEnv,
        [switch]$Wait,
        [switch]$PassThru
    )
    $paths = New-PortableApp -AppName $AppName
    $exePath = Resolve-Path -LiteralPath $Executable -ErrorAction Stop
    $wd = if ($WorkingDirectory) { $WorkingDirectory } else { Split-Path -Parent $exePath.Path }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exePath.Path
    if ($Arguments) { $psi.Arguments = $Arguments }
    $psi.WorkingDirectory = $wd
    $psi.UseShellExecute = $false

    $envMap = @{
        'PORTABLE_ROOT'      = $Script:PortableRoot
        'PORTABLE_APP_ROOT'  = $paths.AppRoot
        'PORTABLE_APP_BIN'   = $paths.Bin
        'PORTABLE_APP_DATA'  = $paths.DataRoot
        'PORTABLE_APPDATA'   = $paths.AppDataRoaming
        'APPDATA'            = $paths.AppDataRoaming
        'LOCALAPPDATA'       = $paths.AppDataLocal
        'USERPROFILE'        = $paths.UserProfile
        'PROGRAMDATA'        = $paths.ProgramData
        'TEMP'               = $paths.Temp
        'TMP'                = $paths.Temp
        'CACHE'              = $paths.Cache
        'LOGPATH'            = $paths.Logs
    }
    foreach ($k in $envMap.Keys) {
        $psi.Environment[$k] = $envMap[$k]
    }
    if ($ExtraEnv) {
        foreach ($item in $ExtraEnv.GetEnumerator()) {
            $psi.Environment[$item.Key] = $item.Value
        }
    }

    $proc = [System.Diagnostics.Process]::Start($psi)
    if ($Wait) {
        $proc.WaitForExit()
        return $proc.ExitCode
    }
    if ($PassThru) { return $proc }
}

function Install-PortableApp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$AppName,
        [Parameter(Mandatory = $true)][string]$InstallerPath,
        [string]$InstallerArgs
    )
    $paths = New-PortableApp -AppName $AppName
    $installer = Resolve-Path -LiteralPath $InstallerPath -ErrorAction Stop
    $args = $InstallerArgs
    if ($args) {
        $replacements = @{
            '{BIN}'      = $paths.Bin
            '{APPROOT}'  = $paths.AppRoot
            '{DATA}'     = $paths.DataRoot
            '{ROAMING}'  = $paths.AppDataRoaming
            '{LOCAL}'    = $paths.AppDataLocal
            '{PROGRAMDATA}' = $paths.ProgramData
            '{USERPROFILE}' = $paths.UserProfile
        }
        foreach ($k in $replacements.Keys) {
            if ($args -like "*$k*") {
                $args = $args.Replace($k, ('"' + $replacements[$k] + '"'))
            }
        }
    }
    Start-PortableApp -AppName $AppName -Executable $installer.Path -Arguments $args -WorkingDirectory (Split-Path -Parent $installer.Path) -Wait
}

# Ayuda rapida cuando se ejecuta directamente
if ($MyInvocation.InvocationName -notin '.', 'source') {
    Initialize-PortableRoot | Out-Null
    Write-Host "Entorno portable inicializado en: $Script:PortableRoot"
    Write-Host 'Importa las funciones con: `. .\portable.ps1`'
    Write-Host 'Ejemplo instalar: Install-PortableApp -AppName "MiApp" -InstallerPath ".\\setup.exe" -InstallerArgs ''/DIR="{BIN}" /S'''
    Write-Host 'Ejemplo lanzar:   Start-PortableApp -AppName "MiApp" -Executable ".\\apps\\MiApp\\bin\\miapp.exe"'
}
