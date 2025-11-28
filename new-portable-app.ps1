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
$form.Size = New-Object System.Drawing.Size(680,360)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false

$title = New-Object System.Windows.Forms.Label
$title.Text = "Carga un instalador y configura la app para que se instale en el sandbox (apps/<App>/bin) y guarde datos en data/<App>/..."
$title.Location = New-Object System.Drawing.Point(10,10)
$title.AutoSize = $true
$title.MaximumSize = New-Object System.Drawing.Size(650,0)
$title.Font = New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Bold)

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

$lblInstaller = New-Label "Instalador (.exe) a importar:" 10 90
$txtInstaller = New-Textbox 250 87 240
$btnInstaller = New-Object System.Windows.Forms.Button
$btnInstaller.Text = "Examinar..."
$btnInstaller.Location = New-Object System.Drawing.Point(500,85)
$btnInstaller.Width = 80

$lblArgs = New-Label "Parámetros del instalador (/DIR={BIN} etc):" 10 120
$txtArgs = New-Textbox 250 117 330
$txtArgs.Text = $defaultArgs

$lblExe = New-Label "Ejecutable relativo tras instalar (apps\\<App>\\bin\\*.exe):" 10 150
$txtExe = New-Textbox 250 147 330

$lblWD = New-Label "WorkingDir relativo (opcional):" 10 180
$txtWD = New-Textbox 250 177 330

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Iniciar instalación portable"
$btnStart.Location = New-Object System.Drawing.Point(400, 230)
$btnStart.Width = 210

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancelar"
$btnCancel.Location = New-Object System.Drawing.Point(290,230)
$btnCancel.Width = 90

$form.Controls.AddRange(@(
    $title,
    $lblName,$txtName,
    $lblInstaller,$txtInstaller,$btnInstaller,
    $lblArgs,$txtArgs,
    $lblExe,$txtExe,
    $lblWD,$txtWD,
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
