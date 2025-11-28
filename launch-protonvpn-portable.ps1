Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $PSCommandPath
Set-Location $here

. "$here\portable.ps1"
Initialize-PortableRoot | Out-Null

Start-PortableApp -AppName 'ProtonVPN' -Executable (Join-Path $here 'apps\ProtonVPN\bin\ProtonVPN.Launcher.exe')
