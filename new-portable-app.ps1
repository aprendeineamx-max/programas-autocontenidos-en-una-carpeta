Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $PSCommandPath
Set-Location $here

. "$here\portable.ps1"
Initialize-PortableRoot | Out-Null

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Drawing.Drawing2D

$defaultArgs = '/DIR="{BIN}" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART'
$baseFont = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Regular)
$baseFontBold = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
$hintColor = [System.Drawing.Color]::FromArgb(120,120,120)

$form = New-Object System.Windows.Forms.Form
$form.Text = "Nuevo programa portable"
$form.Size = New-Object System.Drawing.Size(820, 620)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.Font = $baseFont

# Gradiente de fondo
$form.Add_Paint({
    param($sender,$e)
    $rect = $sender.ClientRectangle
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect,
        [System.Drawing.Color]::FromArgb(245,248,252),
        [System.Drawing.Color]::FromArgb(225,232,245),
        90)
    $e.Graphics.FillRectangle($brush, $rect)
    $brush.Dispose()
})

function New-Label($text, $x, $y, [System.Drawing.Font]$font = $baseFont) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $text
    $lbl.Location = New-Object System.Drawing.Point($x,$y)
    $lbl.AutoSize = $true
    $lbl.Font = $font
    $lbl.BackColor = [System.Drawing.Color]::Transparent
    return $lbl
}
function New-Textbox($x,$y,$w) {
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Location = New-Object System.Drawing.Point($x,$y)
    $tb.Width = $w
    $tb.BorderStyle = 'FixedSingle'
    $tb.BackColor = [System.Drawing.Color]::White
    $tb.Font = $baseFont
    return $tb
}

# Campos
$y = 50
$xLabel = 20
$xBox = 20
$wBox = 760
$gap = 18

function Add-Field([string]$label,[string]$desc,[string]$placeholder,[ref]$y,[switch]$HasButton) {
    $controls = @()
    $lbl = New-Label $label $xLabel $($y.Value) $baseFontBold
    $controls += $lbl
    $y.Value += $gap

    $tbWidth = $wBox - 20
    if ($HasButton) { $tbWidth -= 140 }
    $tb = New-Textbox $xBox $($y.Value) $tbWidth
    $controls += $tb

    if ($placeholder) {
        $tb.Tag = $placeholder
        $tb.ForeColor = $hintColor
        $tb.Text = $placeholder
        $tb.Add_Enter({
            param($sender,$args)
            if ($sender.ForeColor -eq $hintColor -and $sender.Text -eq $sender.Tag) {
                $sender.Text = ""
                $sender.ForeColor = [System.Drawing.Color]::Black
            }
        })
        $tb.Add_Leave({
            param($sender,$args)
            if ([string]::IsNullOrWhiteSpace($sender.Text)) {
                $sender.ForeColor = $hintColor
                $sender.Text = $sender.Tag
            }
        })
    }

    $btn = $null
    if ($HasButton) {
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = "Examinar..."
        $btn.Width = 120
        $btn.Height = 26
        $btn.FlatStyle = 'Flat'
        $btn.BackColor = [System.Drawing.Color]::FromArgb(235,239,247)
        $btn.Location = New-Object System.Drawing.Point($tb.Left + $tb.Width + 10, $tb.Top - 1)
        $controls += $btn
    }

    $y.Value += 28
    if ($desc) {
        $descLbl = New-Label $desc $xLabel $($y.Value) $baseFont
        $descLbl.ForeColor = $hintColor
        $controls += $descLbl
        $y.Value += 24
    } else {
        $y.Value += 10
    }
    return @{ Controls = $controls; TextBox = $tb; Button = $btn }
}

$nameField = Add-Field -label "Nombre de la app (ID)" -desc "Se usa como carpeta: apps/<ID> y data/<ID>." -placeholder "MiApp" -y ([ref]$y)
$txtName = $nameField.TextBox

$installerField = Add-Field -label "Instalador (.exe) a importar" -desc "Se copiará a installers/<ID>.exe" -placeholder "Selecciona un instalador .exe" -y ([ref]$y) -HasButton
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

# Botones
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Iniciar instalacion portable"
$btnStart.Width = 230
$btnStart.Height = 32
$btnStart.FlatStyle = 'Flat'
$btnStart.BackColor = [System.Drawing.Color]::FromArgb(70,120,255)
$btnStart.ForeColor = [System.Drawing.Color]::White
$btnStart.Font = $baseFontBold
$btnStart.Location = New-Object System.Drawing.Point($form.ClientSize.Width - 250, $form.ClientSize.Height - 80)
$btnStart.Anchor = 'Bottom,Right'

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancelar"
$btnCancel.Width = 120
$btnCancel.Height = 32
$btnCancel.FlatStyle = 'Flat'
$btnCancel.BackColor = [System.Drawing.Color]::FromArgb(230,230,230)
$btnCancel.Location = New-Object System.Drawing.Point($form.ClientSize.Width - 380, $form.ClientSize.Height - 80)
$btnCancel.Anchor = 'Bottom,Right'

$form.Controls.AddRange(@($title))
$form.Controls.AddRange($nameField.Controls)
$form.Controls.AddRange($installerField.Controls)
$form.Controls.AddRange($argsField.Controls)
$form.Controls.AddRange($exeField.Controls)
$form.Controls.AddRange($wdField.Controls)
$form.Controls.AddRange(@($btnStart,$btnCancel))

# Eventos
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
    if ([string]::IsNullOrWhiteSpace($safe)) { throw "Nombre invalido." }
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
        if (-not $appNameRaw -or $txtName.ForeColor -eq $hintColor) { throw "Ingresa un nombre de app." }
        $appName = Sanitize-Name $appNameRaw

        $installerSrc = $txtInstaller.Text.Trim()
        if (-not $installerSrc -or -not (Test-Path -LiteralPath $installerSrc) -or $txtInstaller.ForeColor -eq $hintColor) {
            throw "Selecciona un instalador valido."
        }

        $installerArgs = $txtArgs.Text.Trim()
        $exeRel = $txtExe.Text.Trim()
        if (-not $exeRel -or $txtExe.ForeColor -eq $hintColor) {
            $exeRel = "apps/$appName/bin/$appName.exe"
        }
        $wdRel = $txtWD.Text.Trim()
        if (-not $wdRel -or $txtWD.ForeColor -eq $hintColor) {
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

        $rehydrate = Join-Path $here 'rehydrate-all.ps1'
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'powershell.exe'
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$rehydrate`" -AppName `"$appName`" -Launch"
        $psi.UseShellExecute = $true
        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.WaitForExit()
        if ($proc.ExitCode -ne 0) {
            [System.Windows.Forms.MessageBox]::Show("Instalacion portable finalizo con codigo $($proc.ExitCode). Revisa la consola.", "Advertencia", 'OK', 'Warning') | Out-Null
        } else {
            [System.Windows.Forms.MessageBox]::Show("App '$appName' agregada al catalogo y rehidratada.", "Listo", 'OK', 'Information') | Out-Null
        }
        $form.Close()
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Error", 'OK', 'Error') | Out-Null
    }
})

[void]$form.ShowDialog()
