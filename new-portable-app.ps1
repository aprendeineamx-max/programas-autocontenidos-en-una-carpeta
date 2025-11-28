Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $PSCommandPath
Set-Location $here

. "$here\portable.ps1"
Initialize-PortableRoot | Out-Null

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Defaults
$defaultArgs = '/DIR="{BIN}" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART'

$form = New-Object System.Windows.Forms.Form
$form.Text = "Nuevo programa portable"
$form.Size = New-Object System.Drawing.Size(720,420)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false

$title = New-Object System.Windows.Forms.Label
$title.Text = "Carga un instalador y configura la app para que se instale en el sandbox (apps/<App>/bin) y guarde datos en data/<App>/..."
$title.Location = New-Object System.Drawing.Point(10,10)
$title.AutoSize = $true
$title.MaximumSize = New-Object System.Drawing.Size(690,0)
$title.Font = New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Bold)

function New-Separator($y) {
    $sep = New-Object System.Windows.Forms.Label
    $sep.BorderStyle = 'Fixed3D'
    $sep.Width = 670
    $sep.Height = 2
    $sep.Location = New-Object System.Drawing.Point(10,$y)
    return $sep
}

function New-Label($text, $x, $y) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $text
    $lbl.Location = New-Object System.Drawing.Point($x,$y)
    $lbl.AutoSize = $true
    return $lbl
}
function New-Textbox($x,$y,$w) {
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Location = New-Object System.Drawing.Point($x,$y)
    $tb.Width = $w
    return $tb
}

$lblName = New-Label "Nombre de la app (ID):" 10 60
$txtName = New-Textbox 250 57 330
$lblNameDesc = New-Label "(Se usa como carpeta: apps/<ID> y data/<ID>)" 250 80
$lblNameDesc.ForeColor = [System.Drawing.Color]::DimGray
$lblNameDesc.Font = New-Object System.Drawing.Font('Segoe UI',8)

$lblInstaller = New-Label "Instalador (.exe) a importar:" 10 110
$txtInstaller = New-Textbox 250 107 240
$btnInstaller = New-Object System.Windows.Forms.Button
$btnInstaller.Text = "Examinar..."
$btnInstaller.Location = New-Object System.Drawing.Point(500,105)
$btnInstaller.Width = 80
$lblInstallerDesc = New-Label "(Se copiará a installers/<ID>.exe)" 250 130
$lblInstallerDesc.ForeColor = [System.Drawing.Color]::DimGray
$lblInstallerDesc.Font = New-Object System.Drawing.Font('Segoe UI',8)

$lblArgs = New-Label "Parámetros del instalador (/DIR={BIN} etc):" 10 160
$txtArgs = New-Textbox 250 157 330
$txtArgs.Text = $defaultArgs
$lblArgsDesc = New-Label "(Usa tokens: {BIN}, {APPROOT}, {DATA}, {ROAMING}, {LOCAL}, {PROGRAMDATA}, {USERPROFILE})" 250 180
$lblArgsDesc.ForeColor = [System.Drawing.Color]::DimGray
$lblArgsDesc.Font = New-Object System.Drawing.Font('Segoe UI',8)

$lblExe = New-Label "Ejecutable relativo tras instalar (apps\\<App>\\bin\\*.exe):" 10 210
$txtExe = New-Textbox 250 207 330
$lblExeDesc = New-Label "(Ejemplo: apps\\MiApp\\bin\\MiApp.exe)" 250 228
$lblExeDesc.ForeColor = [System.Drawing.Color]::DimGray
$lblExeDesc.Font = New-Object System.Drawing.Font('Segoe UI',8)

$lblWD = New-Label "WorkingDir relativo (opcional):" 10 250
$txtWD = New-Textbox 250 247 330
$lblWDDesc = New-Label "(Por defecto, carpeta del ejecutable)" 250 268
$lblWDDesc.ForeColor = [System.Drawing.Color]::DimGray
$lblWDDesc.Font = New-Object System.Drawing.Font('Segoe UI',8)

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Iniciar instalación portable"
$btnStart.Location = New-Object System.Drawing.Point(420, 300)
$btnStart.Width = 210

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancelar"
$btnCancel.Location = New-Object System.Drawing.Point(310,300)
$btnCancel.Width = 90

$form.Controls.AddRange(@(
    $title,
    (New-Separator 40),
    $lblName,$txtName,$lblNameDesc,
    (New-Separator 95),
    $lblInstaller,$txtInstaller,$btnInstaller,$lblInstallerDesc,
    (New-Separator 145),
    $lblArgs,$txtArgs,$lblArgsDesc,
    (New-Separator 195),
    $lblExe,$txtExe,$lblExeDesc,
    (New-Separator 235),
    $lblWD,$txtWD,$lblWDDesc,
    (New-Separator 285),
    $btnStart,$btnCancel
))

$ofd = New-Object System.Windows.Forms.OpenFileDialog
$ofd.Filter = "Executables (*.exe)|*.exe|All files (*.*)|*.*"
$ofd.Title = "Selecciona el instalador"

$btnInstaller.Add_Click({
    if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtInstaller.Text = $ofd.FileName
    }
})

$btnCancel.Add_Click({ $form.Close() })

function Sanitize-Name($name) {
    $safe = $name -replace '[^a-zA-Z0-9_.-]', '_'
    if ([string]::IsNullOrWhiteSpace($safe)) { throw "Nombre inválido." }
    return $safe
}

function Load-Catalog([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return @() }
    $json = Get-Content -LiteralPath $path -Raw
    if ([string]::IsNullOrWhiteSpace($json)) { return @() }
    return @($json | ConvertFrom-Json)
}

function Save-Catalog([string]$path, $entries) {
    $json = $entries | ConvertTo-Json -Depth 10
    Set-Content -LiteralPath $path -Value $json -Encoding UTF8
}

$btnStart.Add_Click({
    try {
        $appNameRaw = $txtName.Text.Trim()
        if (-not $appNameRaw) { throw "Ingresa un nombre de app." }
        $appName = Sanitize-Name $appNameRaw
        $installerSrc = $txtInstaller.Text.Trim()
        if (-not $installerSrc -or -not (Test-Path -LiteralPath $installerSrc)) {
            throw "Selecciona un instalador válido."
        }
        $installerArgs = $txtArgs.Text.Trim()
        $exeRel = $txtExe.Text.Trim()
        if (-not $exeRel) {
            $exeRel = "apps/$appName/bin/$appName.exe"
        }
        $wdRel = $txtWD.Text.Trim()
        if (-not $wdRel) {
            $wdRel = Split-Path -Parent $exeRel
        }

        $installersDir = Join-Path $here 'installers'
        if (-not (Test-Path -LiteralPath $installersDir)) {
            New-Item -ItemType Directory -Path $installersDir | Out-Null
        }
        $destInstaller = Join-Path $installersDir ("{0}{1}" -f $appName, [IO.Path]::GetExtension($installerSrc))
        Copy-Item -LiteralPath $installerSrc -Destination $destInstaller -Force

        $catalogPath = Join-Path $here 'portable-apps.json'
        $catalog = Load-Catalog $catalogPath
        $catalog = $catalog | Where-Object { $_.name -ne $appName }

        $entry = @{
            name = $appName
            installer = (Resolve-Path -LiteralPath $destInstaller).MakeRelativeUri((Resolve-Path -LiteralPath $here)).OriginalString -replace '^','installers/' -replace '//','/'
        }
        # La conversión anterior puede ser compleja; mejor asignamos ruta relativa directa:
        $entry.installer = ("installers/{0}" -f (Split-Path -Leaf $destInstaller))
        $entry.installerArgs = $installerArgs
        $entry.executable = $exeRel
        $entry.launchArgs = ""
        $entry.workingDir = $wdRel
        $entry.dataPaths = @(
            "data/$appName/AppData/Local",
            "data/$appName/AppData/Roaming",
            "data/$appName/ProgramData",
            "data/$appName/UserProfile",
            "data/$appName/Temp"
        )
        $entry.knownExternalPaths = @(
            "%APPDATA%/$appName*",
            "%LOCALAPPDATA%/$appName*",
            "%PROGRAMDATA%/$appName*"
        )
        $entry.notes = ""

        $catalog += New-Object PSObject -Property $entry
        Save-Catalog -path $catalogPath -entries $catalog

        # Ejecutar rehidratado de la app
        $rehydrate = Join-Path $here 'rehydrate-all.ps1'
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'powershell.exe'
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$rehydrate`" -AppName `"$appName`" -Launch"
        $psi.UseShellExecute = $true
        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.WaitForExit()
        if ($proc.ExitCode -ne 0) {
            [System.Windows.Forms.MessageBox]::Show("Instalación portable finalizó con código $($proc.ExitCode). Revisa la consola.", "Advertencia", 'OK', 'Warning') | Out-Null
        } else {
            [System.Windows.Forms.MessageBox]::Show("App '$appName' agregada al catálogo y rehidratada.", "Listo", 'OK', 'Information') | Out-Null
        }
        $form.Close()
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Error", 'OK', 'Error') | Out-Null
    }
})

[void]$form.ShowDialog()
