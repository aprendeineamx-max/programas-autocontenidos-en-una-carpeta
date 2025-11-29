Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $PSCommandPath
Set-Location $here

. "$here\portable.ps1"
Initialize-PortableRoot | Out-Null

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Args por defecto (Inno Setup): ubicación, silencio, sin reinicio, sin splash, con log en data/<App>
$defaultArgs = '/DIR="{BIN}" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /LOG="{DATA}\install.log"'

function Get-Themes {
    return @{
        "Deep Obsidian" = @{
            BackColor   = [System.Drawing.Color]::FromArgb(26,28,34)
            PanelColor  = [System.Drawing.Color]::FromArgb(38,40,48)
            TextColor   = [System.Drawing.Color]::FromArgb(230,232,236)
            HintColor   = [System.Drawing.Color]::FromArgb(140,140,150)
            Accent      = [System.Drawing.Color]::FromArgb(88,140,255)
            ButtonBack  = [System.Drawing.Color]::FromArgb(46,50,60)
        }
        "Dark" = @{
            BackColor   = [System.Drawing.Color]::FromArgb(30,32,38)
            PanelColor  = [System.Drawing.Color]::FromArgb(42,44,52)
            TextColor   = [System.Drawing.Color]::FromArgb(242,244,248)
            HintColor   = [System.Drawing.Color]::FromArgb(175,177,185)
            Accent      = [System.Drawing.Color]::FromArgb(96,152,255)
            ButtonBack  = [System.Drawing.Color]::FromArgb(62,64,74)
        }
        "Claro" = @{
            BackColor   = [System.Drawing.Color]::White
            PanelColor  = [System.Drawing.Color]::FromArgb(245,245,245)
            TextColor   = [System.Drawing.Color]::FromArgb(20,20,20)
            HintColor   = [System.Drawing.Color]::FromArgb(110,110,110)
            Accent      = [System.Drawing.Color]::FromArgb(70,120,255)
            ButtonBack  = [System.Drawing.Color]::FromArgb(235,235,235)
        }
        "Gris" = @{
            BackColor   = [System.Drawing.Color]::FromArgb(232,232,236)
            PanelColor  = [System.Drawing.Color]::FromArgb(244,244,247)
            TextColor   = [System.Drawing.Color]::FromArgb(25,25,25)
            HintColor   = [System.Drawing.Color]::FromArgb(120,120,130)
            Accent      = [System.Drawing.Color]::FromArgb(64,96,180)
            ButtonBack  = [System.Drawing.Color]::FromArgb(220,220,225)
        }
    }
}

function New-Label {
    param(
        [string]$Text,
        [System.Drawing.Font]$Font = $null,
        [System.Drawing.Color]$ForeColor = $null
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
        [string]$Placeholder = "",
        [System.Drawing.Color]$HintColor = [System.Drawing.Color]::Gray,
        [System.Drawing.Color]$BackColor = $null,
        [System.Drawing.Color]$TextColor = $null
    )
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Text = $Text
    $tb.Dock = 'Fill'
    $tb.Margin = '3,3,3,3'
    if ($BackColor) { $tb.BackColor = $BackColor }
    if ($TextColor) { $tb.ForeColor = $TextColor }
    if ($Placeholder -and -not $Text) {
        $tb.Text = $Placeholder
        $tb.Tag = $Placeholder
        $tb.ForeColor = $HintColor
        $tb.Add_Enter({
            param($s,$e)
            if ($s.Text -eq $s.Tag -and $s.ForeColor -ne [System.Drawing.Color]::Black) {
                $s.Text = ""
                $s.ForeColor = [System.Drawing.Color]::Black
            }
        })
        $tb.Add_Leave({
            param($s,$e)
            if ([string]::IsNullOrWhiteSpace($s.Text)) {
                $s.Text = $s.Tag
                $s.ForeColor = $HintColor
            }
        })
    } elseif (-not $Placeholder -and $TextColor) {
        $tb.ForeColor = $TextColor
    }
    return $tb
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Nuevo programa portable"
$form.Size = New-Object System.Drawing.Size(920,640)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'Sizable'
$form.MaximizeBox = $true
$form.MinimizeBox = $true
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$themes = Get-Themes
$currentTheme = $themes["Dark"]
$textColor = $currentTheme.TextColor
$hintColor = $currentTheme.HintColor

$main = New-Object System.Windows.Forms.TableLayoutPanel
$main.Dock = 'Fill'
$main.ColumnCount = 1
$main.RowCount = 1
$main.Padding = '12,12,12,12'
$main.AutoScroll = $true
$main.AutoSize = $true
$main.GrowStyle = 'AddRows'

$bold = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

# Panel de tema
$themePanel = New-Object System.Windows.Forms.FlowLayoutPanel
$themePanel.Dock = 'Top'
$themePanel.AutoSize = $true
$themePanel.Margin = '0,0,0,10'
$lblTheme = New-Label -Text "Tema:" -Font $bold -ForeColor $textColor
$cmbTheme = New-Object System.Windows.Forms.ComboBox
$cmbTheme.DropDownStyle = 'DropDownList'
$cmbTheme.Width = 180
$cmbTheme.Items.AddRange($themes.Keys)
$cmbTheme.SelectedItem = "Dark"
$themePanel.Controls.Add($lblTheme)
$themePanel.Controls.Add($cmbTheme)

# Título principal
$title = New-Label -Text "Carga un instalador y configura la app para que se instale en el sandbox (apps/<App>/bin) y guarde datos en data/<App>/..." -Font $bold -ForeColor $textColor
$title.MaximumSize = New-Object System.Drawing.Size(880,0)
$title.Margin = '3,3,3,8'
$main.Controls.Add($themePanel)
$main.Controls.Add($title)

# Checkboxes helpers
function New-Check($text, [bool]$state) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $text
    $cb.Checked = $state
    $cb.AutoSize = $true
    $cb.Margin = '0,0,10,5'
    return $cb
}

$checksPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$checksPanel.AutoSize = $true
$checksPanel.Dock = 'Top'
$checksPanel.FlowDirection = 'LeftToRight'
$checksPanel.WrapContents = $true
$checksPanel.Margin = '0,0,0,5'

$cbDir       = New-Check '/DIR="{BIN}"' $true
$cbSilent    = New-Check '/VERYSILENT' $true
$cbSuppress  = New-Check '/SUPPRESSMSGBOXES' $true
$cbNoRestart = New-Check '/NORESTART' $true
$cbSP        = New-Check '/SP-' $true
$cbLog       = New-Check '/LOG="{DATA}\install.log"' $true
$cbNoIcons   = New-Check '/NOICONS' $false
$cbMergeNoIcons = New-Check '/MERGETASKS="!desktopicon,!startmenuicon"' $false
$cbCurrentUser = New-Check '/CURRENTUSER' $false
$cbAllUsers  = New-Check '/ALLUSERS' $false
$cbNoCancel  = New-Check '/NOCANCEL' $false
$cbNoClose   = New-Check '/NOCLOSEAPPLICATIONS' $false
$cbCloseApps = New-Check '/CLOSEAPPLICATIONS' $false
$cbForceClose = New-Check '/FORCECLOSEAPPLICATIONS' $false
$checksPanel.Controls.AddRange(@(
    $cbDir,$cbSilent,$cbSuppress,$cbNoRestart,$cbSP,$cbLog,
    $cbNoIcons,$cbMergeNoIcons,$cbCurrentUser,$cbAllUsers,$cbNoCancel,$cbNoClose,$cbCloseApps,$cbForceClose
))

# Panel avanzado (lang/tasks/components/inf)
$advancedPanel = New-Object System.Windows.Forms.TableLayoutPanel
$advancedPanel.ColumnCount = 2
$advancedPanel.RowCount = 4
$advancedPanel.AutoSize = $true
$advancedPanel.Dock = 'Top'
$advancedPanel.Margin = '0,0,0,10'
$advancedPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute',150)))
$advancedPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent',100)))

function Add-AdvancedRow($label,$control) {
    $r = $advancedPanel.RowCount - 1
    $advancedPanel.Controls.Add((New-Label -Text $label -ForeColor $hintColor),0,$r)
    $control.Dock = 'Fill'
    $advancedPanel.Controls.Add($control,1,$r)
    $advancedPanel.RowCount += 1
}

$txtLang = New-TextBox -Text "" -Placeholder "es" -HintColor $hintColor -BackColor $currentTheme.PanelColor -TextColor $textColor
$txtTasks = New-TextBox -Text "" -Placeholder "task1,task2" -HintColor $hintColor -BackColor $currentTheme.PanelColor -TextColor $textColor
$txtComponents = New-TextBox -Text "" -Placeholder "comp1,comp2" -HintColor $hintColor -BackColor $currentTheme.PanelColor -TextColor $textColor
$txtLoadInf = New-TextBox -Text "" -Placeholder "ruta\\setup.inf" -HintColor $hintColor -BackColor $currentTheme.PanelColor -TextColor $textColor
$txtSaveInf = New-TextBox -Text "" -Placeholder "ruta\\respuesta.inf" -HintColor $hintColor -BackColor $currentTheme.PanelColor -TextColor $textColor
$cbLoadInf = New-Check '/LOADINF' $false
$cbSaveInf = New-Check '/SAVEINF' $false

Add-AdvancedRow "LANG (si aplica):" $txtLang
Add-AdvancedRow "TASKS (si aplica):" $txtTasks
Add-AdvancedRow "COMPONENTS (si aplica):" $txtComponents

$loadPanel = New-Object System.Windows.Forms.TableLayoutPanel
$loadPanel.ColumnCount = 2
$loadPanel.RowCount = 1
$loadPanel.AutoSize = $true
$loadPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute',80)))
$loadPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent',100)))
$loadPanel.Controls.Add($cbLoadInf,0,0)
$loadPanel.Controls.Add($txtLoadInf,1,0)

$savePanel = New-Object System.Windows.Forms.TableLayoutPanel
$savePanel.ColumnCount = 2
$savePanel.RowCount = 1
$savePanel.AutoSize = $true
$savePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute',80)))
$savePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent',100)))
$savePanel.Controls.Add($cbSaveInf,0,0)
$savePanel.Controls.Add($txtSaveInf,1,0)

Add-AdvancedRow "LOADINF (opcional):" $loadPanel
Add-AdvancedRow "SAVEINF (opcional):" $savePanel

$infoFlags = New-Label -Text "Opciones recomendadas ya vienen marcadas. Avanzadas (LANG/TASKS/COMPONENTS/LOADINF/SAVEINF) solo si el instalador las soporta. /ALLUSERS o /CURRENTUSER según se requiera; /NOICONS y /MERGETASKS para evitar accesos directos; /NOCANCEL y /NOCLOSEAPPLICATIONS solo si quieres forzar sin intervención; /CLOSEAPPLICATIONS y /FORCECLOSEAPPLICATIONS reinician procesos, úsalo con cautela." -ForeColor $hintColor
$infoFlags.MaximumSize = New-Object System.Drawing.Size(880,0)
$main.Controls.Add($infoFlags)
$main.Controls.Add($checksPanel)
$main.Controls.Add($advancedPanel)

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

    $lbl = New-Label -Text $Label -Font $bold -ForeColor $textColor
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

# Campos principales
$txtName = New-TextBox -Text "" -Placeholder "MiApp" -HintColor $hintColor -BackColor $currentTheme.PanelColor -TextColor $textColor
Add-FieldRow -Label "Nombre de la app (ID)" -Description "Se usa como carpeta: apps/<ID> y data/<ID>." -InputControl $txtName

$txtInstaller = New-TextBox -Text "" -Placeholder "Selecciona instalador .exe" -HintColor $hintColor -BackColor $currentTheme.PanelColor -TextColor $textColor
$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Examinar..."
$btnBrowse.FlatStyle = 'Flat'
$btnBrowse.BackColor = $currentTheme.ButtonBack
$btnBrowse.ForeColor = $textColor
$btnBrowse.Margin = '6,3,3,3'
Add-FieldRow -Label "Instalador (.exe) a importar" -Description "Se copiara a installers/<ID>.exe" -InputControl $txtInstaller -ButtonControl $btnBrowse

$txtArgs = New-TextBox -Text "" -Placeholder "Extra args (opcional)" -HintColor $hintColor -BackColor $currentTheme.PanelColor -TextColor $textColor
Add-FieldRow -Label "Parámetros extra (opcional)" -Description "Se agregarán después de las opciones marcadas. Tokens: {BIN}, {APPROOT}, {DATA}, {ROAMING}, {LOCAL}, {PROGRAMDATA}, {USERPROFILE}" -InputControl $txtArgs

$txtExe = New-TextBox -Text "" -Placeholder "apps\\MiApp\\bin\\MiApp.exe" -HintColor $hintColor -BackColor $currentTheme.PanelColor -TextColor $textColor
Add-FieldRow -Label "Ejecutable relativo tras instalar" -Description "Ejemplo: apps\\MiApp\\bin\\MiApp.exe" -InputControl $txtExe

$txtWD = New-TextBox -Text "" -Placeholder "apps\\MiApp\\bin" -HintColor $hintColor -BackColor $currentTheme.PanelColor -TextColor $textColor
Add-FieldRow -Label "WorkingDir relativo (opcional)" -Description "Por defecto, la carpeta del ejecutable." -InputControl $txtWD

# Botones inferiores
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Iniciar instalacion portable"
$btnStart.Width = 200
$btnStart.Height = 32
$btnStart.FlatStyle = 'Flat'
$btnStart.BackColor = $currentTheme.Accent
$btnStart.ForeColor = [System.Drawing.Color]::White
$btnStart.Font = $bold

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancelar"
$btnCancel.Width = 100
$btnCancel.Height = 32
$btnCancel.FlatStyle = 'Flat'
$btnCancel.BackColor = $currentTheme.ButtonBack
$btnCancel.ForeColor = $textColor

$buttons = New-Object System.Windows.Forms.FlowLayoutPanel
$buttons.FlowDirection = 'RightToLeft'
$buttons.Dock = 'Bottom'
$buttons.Height = 50
$buttons.Padding = '0,5,0,5'
$buttons.Controls.Add($btnStart)
$buttons.Controls.Add($btnCancel)

$form.Controls.Add($buttons)
$form.Controls.Add($main)

# Browse
$ofd = New-Object System.Windows.Forms.OpenFileDialog
$ofd.Filter = "Executables (*.exe)|*.exe|All files (*.*)|*.*"
$ofd.Title = "Selecciona el instalador"
$btnBrowse.Add_Click({
    if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtInstaller.Text = $ofd.FileName
        $txtInstaller.ForeColor = $textColor
    }
})

$btnCancel.Add_Click({ $form.Close() })

function Apply-Theme($name) {
    $t = $themes[$name]
    if (-not $t) { return }
    $form.BackColor = $t.BackColor
    $main.BackColor = $t.BackColor
    $textColor = $t.TextColor
    $hintColor = $t.HintColor
    foreach ($container in $main.Controls) {
        $container.BackColor = $t.BackColor
        foreach ($ctrl in $container.Controls) {
            if ($ctrl -is [System.Windows.Forms.Label]) {
                if ($ctrl.Font.Bold) { $ctrl.ForeColor = $t.TextColor } else { $ctrl.ForeColor = $t.HintColor }
            }
            if ($ctrl -is [System.Windows.Forms.TableLayoutPanel] -or $ctrl -is [System.Windows.Forms.FlowLayoutPanel]) {
                $ctrl.BackColor = $t.BackColor
                foreach ($inner in $ctrl.Controls) {
                    if ($inner -is [System.Windows.Forms.TextBox]) {
                        $inner.BackColor = $t.PanelColor
                        if ($inner.ForeColor -ne [System.Drawing.Color]::Gray) { $inner.ForeColor = $t.TextColor }
                    }
                    if ($inner -is [System.Windows.Forms.Label]) {
                        if ($inner.Font.Bold) { $inner.ForeColor = $t.TextColor } else { $inner.ForeColor = $t.HintColor }
                    }
                    if ($inner -is [System.Windows.Forms.Button]) {
                        $inner.BackColor = $t.ButtonBack
                        $inner.ForeColor = $t.TextColor
                        if ($inner -eq $btnStart) { $inner.BackColor = $t.Accent; $inner.ForeColor = [System.Drawing.Color]::White }
                    }
                    if ($inner -is [System.Windows.Forms.CheckBox]) {
                        $inner.ForeColor = $t.TextColor
                    }
                }
            }
            if ($ctrl -is [System.Windows.Forms.CheckBox]) {
                $ctrl.ForeColor = $t.TextColor
            }
        }
    }
    $btnStart.BackColor = $t.Accent
    $btnStart.ForeColor = [System.Drawing.Color]::White
    $btnCancel.BackColor = $t.ButtonBack
    $btnCancel.ForeColor = $t.TextColor
}

$cmbTheme.Add_SelectedIndexChanged({
    Apply-Theme -name $cmbTheme.SelectedItem
})

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

        $argList = @()
        if ($cbDir.Checked)       { $argList += '/DIR="{BIN}"' }
        if ($cbSilent.Checked)    { $argList += '/VERYSILENT' }
        if ($cbSuppress.Checked)  { $argList += '/SUPPRESSMSGBOXES' }
        if ($cbNoRestart.Checked) { $argList += '/NORESTART' }
        if ($cbSP.Checked)        { $argList += '/SP-' }
        if ($cbLog.Checked)       { $argList += '/LOG="{DATA}\install.log"' }
        if ($cbNoIcons.Checked)   { $argList += '/NOICONS' }
        if ($cbMergeNoIcons.Checked) { $argList += '/MERGETASKS="!desktopicon,!startmenuicon"' }
        if ($cbCurrentUser.Checked) { $argList += '/CURRENTUSER' }
        if ($cbAllUsers.Checked)    { $argList += '/ALLUSERS' }
        if ($cbNoCancel.Checked)    { $argList += '/NOCANCEL' }
        if ($cbNoClose.Checked)     { $argList += '/NOCLOSEAPPLICATIONS' }
        if ($cbCloseApps.Checked)   { $argList += '/CLOSEAPPLICATIONS' }
        if ($cbForceClose.Checked)  { $argList += '/FORCECLOSEAPPLICATIONS' }
        if ($cbLoadInf.Checked -and $txtLoadInf.Text.Trim()) { $argList += "/LOADINF=""$($txtLoadInf.Text.Trim())""" }
        if ($cbSaveInf.Checked -and $txtSaveInf.Text.Trim()) { $argList += "/SAVEINF=""$($txtSaveInf.Text.Trim())""" }
        if ($txtLang.Text.Trim())        { $argList += "/LANG=""$($txtLang.Text.Trim())""" }
        if ($txtTasks.Text.Trim())       { $argList += "/TASKS=""$($txtTasks.Text.Trim())""" }
        if ($txtComponents.Text.Trim())  { $argList += "/COMPONENTS=""$($txtComponents.Text.Trim())""" }
        $extra = $txtArgs.Text.Trim()
        if ($extra -and $txtArgs.ForeColor -ne $hintColor) { $argList += $extra }
        $installerArgs = ($argList -join ' ').Trim()

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

$cmbTheme.Add_SelectedIndexChanged({ Apply-Theme -name $cmbTheme.SelectedItem })
Apply-Theme -name $cmbTheme.SelectedItem

[void]$form.ShowDialog()
