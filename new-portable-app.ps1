Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $PSCommandPath
Set-Location $here

. "$here\portable.ps1"
Initialize-PortableRoot | Out-Null

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$defaultArgs = '/DIR="{BIN}" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART'

# Helpers
function New-Label {
    param(
        [string]$Text,
        [System.Drawing.Font]$Font,
        [System.Drawing.Color]$ForeColor
    )
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Text
    if ($Font) { $lbl.Font = $Font }
    if ($ForeColor) { $lbl.ForeColor = $ForeColor }
    $lbl.AutoSize = $true
    $lbl.Margin = '3,6,3,3'
    return $lbl
}

function New-TextBox {
    param(
        [string]$Text,
        [string]$Placeholder = ""
    )
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Text = $Text
    $tb.Dock = 'Fill'
    $tb.Margin = '3,3,3,3'
    if ($Placeholder -and -not $Text) {
        $tb.Text = $Placeholder
        $tb.Tag = $Placeholder
        $tb.ForeColor = [System.Drawing.Color]::Gray
        $tb.Add_Enter({
            param($s,$e)
            if ($s.ForeColor -eq [System.Drawing.Color]::Gray -and $s.Text -eq $s.Tag) {
                $s.Text = ""
                $s.ForeColor = [System.Drawing.Color]::Black
            }
        })
        $tb.Add_Leave({
            param($s,$e)
            if ([string]::IsNullOrWhiteSpace($s.Text)) {
                $s.Text = $s.Tag
                $s.ForeColor = [System.Drawing.Color]::Gray
            }
        })
    }
    return $tb
}

# Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Nuevo programa portable"
$form.Size = New-Object System.Drawing.Size(720,520)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'Sizable'
$form.MaximizeBox = $true
$form.MinimizeBox = $true
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$main = New-Object System.Windows.Forms.TableLayoutPanel
$main.Dock = 'Fill'
$main.ColumnCount = 1
$main.RowCount = 1
$main.Padding = '12,12,12,12'
$main.AutoScroll = $true
$main.AutoSize = $true
$main.GrowStyle = 'AddRows'

$bold = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
$hintColor = [System.Drawing.Color]::FromArgb(110,110,110)

# Título principal
$title = New-Label -Text "Carga un instalador y configura la app para que se instale en el sandbox (apps/<App>/bin) y guarde datos en data/<App>/..." -Font $bold
$title.MaximumSize = New-Object System.Drawing.Size(700,0)
$title.Margin = '3,3,3,8'
$main.Controls.Add($title)

function Add-FieldRow {
    param(
        [string]$Label,
        [string]$Description,
        [System.Windows.Forms.Control]$InputControl,
        [System.Windows.Forms.Control]$ButtonControl = $null
    )
    $panel = New-Object System.Windows.Forms.TableLayoutPanel
    $panel.ColumnCount = $(if ($ButtonControl) {2} else {1})
    if ($ButtonControl) {
        $panel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
        $panel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute', 110)))
    } else {
        $panel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
    }
    $panel.RowCount = 1
    $panel.Dock = 'Top'
    $panel.AutoSize = $true
    $panel.Margin = '0,0,0,5'

    if ($ButtonControl) {
        $InputControl.Dock = 'Fill'
        $ButtonControl.Dock = 'Fill'
        $panel.Controls.Add($InputControl,0,0)
        $panel.Controls.Add($ButtonControl,1,0)
    } else {
        $InputControl.Dock = 'Fill'
        $panel.Controls.Add($InputControl,0,0)
    }

    $lbl = New-Label -Text $Label -Font $bold
    $desc = $null
    if ($Description) {
        $desc = New-Label -Text $Description -ForeColor $hintColor
    }

    $container = New-Object System.Windows.Forms.TableLayoutPanel
    $container.ColumnCount = 1
    $container.RowCount = 3
    $container.AutoSize = $true
    $container.Dock = 'Top'
    $container.Margin = '0,0,0,10'
    $container.Controls.Add($lbl,0,0)
    $container.Controls.Add($panel,0,1)
    if ($desc) { $container.Controls.Add($desc,0,2) }

    $main.Controls.Add($container)
}

# Campos
$txtName = New-TextBox -Text "" -Placeholder "MiApp"
Add-FieldRow -Label "Nombre de la app (ID)" -Description "Se usa como carpeta: apps/<ID> y data/<ID>." -InputControl $txtName

$txtInstaller = New-TextBox -Text "" -Placeholder "Selecciona instalador .exe"
$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Examinar..."
$btnBrowse.FlatStyle = 'Flat'
Add-FieldRow -Label "Instalador (.exe) a importar" -Description "Se copiara a installers/<ID>.exe" -InputControl $txtInstaller -ButtonControl $btnBrowse

$txtArgs = New-TextBox -Text $defaultArgs
Add-FieldRow -Label "Parametros del instalador (/DIR={BIN} etc)" -Description "Tokens: {BIN}, {APPROOT}, {DATA}, {ROAMING}, {LOCAL}, {PROGRAMDATA}, {USERPROFILE}" -InputControl $txtArgs

$txtExe = New-TextBox -Text "" -Placeholder "apps\\MiApp\\bin\\MiApp.exe"
Add-FieldRow -Label "Ejecutable relativo tras instalar" -Description "Ejemplo: apps\\MiApp\\bin\\MiApp.exe" -InputControl $txtExe

$txtWD = New-TextBox -Text "" -Placeholder "apps\\MiApp\\bin"
Add-FieldRow -Label "WorkingDir relativo (opcional)" -Description "Por defecto, la carpeta del ejecutable." -InputControl $txtWD

# Botones inferiores
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Iniciar instalacion portable"
$btnStart.Width = 200
$btnStart.Height = 32
$btnStart.FlatStyle = 'Flat'
$btnStart.BackColor = [System.Drawing.Color]::FromArgb(70,120,255)
$btnStart.ForeColor = [System.Drawing.Color]::White
$btnStart.Font = $bold

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancelar"
$btnCancel.Width = 100
$btnCancel.Height = 32
$btnCancel.FlatStyle = 'Flat'
$btnCancel.BackColor = [System.Drawing.Color]::FromArgb(230,230,230)

$buttons = New-Object System.Windows.Forms.FlowLayoutPanel
$buttons.FlowDirection = 'RightToLeft'
$buttons.Dock = 'Bottom'
$buttons.Height = 50
$buttons.Padding = '0,5,0,5'
$buttons.Controls.Add($btnStart)
$buttons.Controls.Add($btnCancel)

$form.Controls.Add($buttons)
$form.Controls.Add($main)
$main.Controls.Add($title)

# Browse
$ofd = New-Object System.Windows.Forms.OpenFileDialog
$ofd.Filter = "Executables (*.exe)|*.exe|All files (*.*)|*.*"
$ofd.Title = "Selecciona el instalador"
$btnBrowse.Add_Click({
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
        if (-not $appNameRaw -or $txtName.ForeColor -eq [System.Drawing.Color]::Gray) { throw "Ingresa un nombre de app." }
        $appName = Sanitize-Name $appNameRaw

        $installerSrc = $txtInstaller.Text.Trim()
        if (-not $installerSrc -or -not (Test-Path -LiteralPath $installerSrc) -or $txtInstaller.ForeColor -eq [System.Drawing.Color]::Gray) {
            throw "Selecciona un instalador valido."
        }

        $installerArgs = $txtArgs.Text.Trim()
        $exeRel = $txtExe.Text.Trim()
        if (-not $exeRel -or $txtExe.ForeColor -eq [System.Drawing.Color]::Gray) {
            $exeRel = "apps/$appName/bin/$appName.exe"
        }
        $wdRel = $txtWD.Text.Trim()
        if (-not $wdRel -or $txtWD.ForeColor -eq [System.Drawing.Color]::Gray) {
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
