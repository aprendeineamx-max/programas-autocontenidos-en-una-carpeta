Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $PSCommandPath
Set-Location $here

. "$here\portable.ps1"
Initialize-PortableRoot | Out-Null

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$defaultArgs = '/DIR="{BIN}" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART'

$form = New-Object System.Windows.Forms.Form
$form.Text = "Nuevo programa portable"
$form.Size = New-Object System.Drawing.Size(760,560)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false

$title = New-Object System.Windows.Forms.Label
$title.Text = "Carga un instalador y configura la app para que se instale en el sandbox (apps/<App>/bin) y guarde datos en data/<App>/..."
$title.Location = New-Object System.Drawing.Point(12,12)
$title.AutoSize = $true
$title.MaximumSize = New-Object System.Drawing.Size(720,0)
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

$y = 50
$x = 12
$w = 720

function Add-Field([string]$label,[string]$desc,[string]$placeholder,[ref]$y,[switch]$HasButton) {
    $controls = @()
    $lbl = New-Label $label $x $($y.Value)
    $lbl.Font = New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Regular)
    $controls += $lbl
    $y.Value += 20

    $tbWidth = $w - 40
    if ($HasButton) { $tbWidth -= 120 }
    $tb = New-Textbox $x $($y.Value) $tbWidth
    $controls += $tb

    if ($placeholder) {
        $tb.ForeColor = [System.Drawing.Color]::DimGray
        $tb.Text = $placeholder
        $tb.Add_Enter({
            if ($tb.ForeColor -eq [System.Drawing.Color]::DimGray) {
                $tb.Text = ""
                $tb.ForeColor = [System.Drawing.Color]::Black
            }
        })
        $tb.Add_Leave({
            if ([string]::IsNullOrWhiteSpace($tb.Text)) {
                $tb.ForeColor = [System.Drawing.Color]::DimGray
                $tb.Text = $placeholder
            }
        })
    }

    $btn = $null
    if ($HasButton) {
        $textBoxRef = $tb
        if ($textBoxRef -is [System.Array]) { $textBoxRef = $textBoxRef | Select-Object -First 1 }
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = "Examinar..."
        $btn.Width = 100
        $btn.Location = New-Object System.Drawing.Point($textBoxRef.Left + $textBoxRef.Width + 10, $textBoxRef.Top - 1)
        $controls += $btn
    }

    $y.Value += 26
    if ($desc) {
        $descLbl = New-Label $desc $x $($y.Value)
        $descLbl.ForeColor = [System.Drawing.Color]::DimGray
        $descLbl.Font = New-Object System.Drawing.Font('Segoe UI',8)
        $controls += $descLbl
        $y.Value += 26
    } else {
        $y.Value += 10
    }
    return @{ Controls = $controls; TextBox = $tb; Button = $btn }
}

$nameField = Add-Field -label "Nombre de la app (ID)" -desc "Se usa como carpeta: apps/<ID> y data/<ID>." -placeholder "MiApp" -y ([ref]$y)
$txtName = $nameField.TextBox

$installerField = Add-Field -label "Instalador (.exe) a importar" -desc "Se copiará a installers/<ID>.exe" -placeholder "Selecciona un .exe" -y ([ref]$y) -HasButton
$txtInstaller = $installerField.TextBox
$btnInstaller = $installerField.Button

$argsField = Add-Field -label "Parámetros del instalador (/DIR={BIN} etc)" -desc "Tokens: {BIN}, {APPROOT}, {DATA}, {ROAMING}, {LOCAL}, {PROGRAMDATA}, {USERPROFILE}" -placeholder "/DIR=""{BIN}"" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -y ([ref]$y)
$txtArgs = $argsField.TextBox
$txtArgs.ForeColor = [System.Drawing.Color]::Black
$txtArgs.Text = $defaultArgs

$exeField = Add-Field -label "Ejecutable relativo tras instalar" -desc "Ejemplo: apps\\MiApp\\bin\\MiApp.exe" -placeholder "apps\\MiApp\\bin\\MiApp.exe" -y ([ref]$y)
$txtExe = $exeField.TextBox

$wdField = Add-Field -label "WorkingDir relativo (opcional)" -desc "Por defecto, la carpeta del ejecutable." -placeholder "apps\\MiApp\\bin" -y ([ref]$y)
$txtWD = $wdField.TextBox

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Iniciar instalación portable"
$btnStart.Width = 220
$btnStart.Location = New-Object System.Drawing.Point($form.ClientSize.Width - 240, $form.ClientSize.Height - 60)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancelar"
$btnCancel.Width = 100
$btnCancel.Location = New-Object System.Drawing.Point($form.ClientSize.Width - 350, $form.ClientSize.Height - 60)

$form.Controls.AddRange(@($title))
$form.Controls.AddRange($nameField.Controls)
$form.Controls.AddRange($installerField.Controls)
$form.Controls.AddRange($argsField.Controls)
$form.Controls.AddRange($exeField.Controls)
$form.Controls.AddRange($wdField.Controls)
$form.Controls.AddRange(@($btnStart,$btnCancel))

$ofd = New-Object System.Windows.Forms.OpenFileDialog
$ofd.Filter = "Executables (*.exe)|*.exe|All files (*.*)|*.*"
$ofd.Title = "Selecciona el instalador"

$btnInstaller.Add_Click({
    if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtInstaller.Text = $ofd.FileName
        $txtInstaller.ForeColor = [System.Drawing.Color]::Black
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
        if (-not $appNameRaw -or $txtName.ForeColor -eq [System.Drawing.Color]::DimGray) { throw "Ingresa un nombre de app." }
        $appName = Sanitize-Name $appNameRaw
        $installerSrc = $txtInstaller.Text.Trim()
        if (-not $installerSrc -or -not (Test-Path -LiteralPath $installerSrc) -or $txtInstaller.ForeColor -eq [System.Drawing.Color]::DimGray) {
            throw "Selecciona un instalador válido."
        }
        $installerArgs = $txtArgs.Text.Trim()
        $exeRel = $txtExe.Text.Trim()
        if (-not $exeRel -or $txtExe.ForeColor -eq [System.Drawing.Color]::DimGray) {
            $exeRel = "apps/$appName/bin/$appName.exe"
        }
        $wdRel = $txtWD.Text.Trim()
        if (-not $wdRel -or $txtWD.ForeColor -eq [System.Drawing.Color]::DimGray) {
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
            installer = ("installers/{0}" -f (Split-Path -Leaf $destInstaller))
            installerArgs = $installerArgs
            executable = $exeRel
            launchArgs = ""
            workingDir = $wdRel
            dataPaths = @(
                "data/$appName/AppData/Local",
                "data/$appName/AppData/Roaming",
                "data/$appName/ProgramData",
                "data/$appName/UserProfile",
                "data/$appName/Temp"
            )
            knownExternalPaths = @(
                "%APPDATA%/$appName*",
                "%LOCALAPPDATA%/$appName*",
                "%PROGRAMDATA%/$appName*"
            )
            notes = ""
        }

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
