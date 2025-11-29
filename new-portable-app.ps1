Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $PSCommandPath
Set-Location $here

. "$here\portable.ps1"
Initialize-PortableRoot | Out-Null

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$defaultArgs = '/DIR="{BIN}" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /LOG="{DATA}\install.log"'

function Get-Themes {
    return @{
        "Dark" = @{
            BackColor   = [System.Drawing.Color]::FromArgb(28,30,36)
            PanelColor  = [System.Drawing.Color]::FromArgb(40,42,50)
            TextColor   = [System.Drawing.Color]::FromArgb(240,242,248)
            HintColor   = [System.Drawing.Color]::FromArgb(175,177,185)
            Accent      = [System.Drawing.Color]::FromArgb(96,152,255)
            ButtonBack  = [System.Drawing.Color]::FromArgb(60,64,74)
            BorderColor = [System.Drawing.Color]::FromArgb(90,92,100)
            SectionBack = [System.Drawing.Color]::FromArgb(36,38,46)
        }
        "Claro" = @{
            BackColor   = [System.Drawing.Color]::White
            PanelColor  = [System.Drawing.Color]::FromArgb(245,245,245)
            TextColor   = [System.Drawing.Color]::FromArgb(20,20,20)
            HintColor   = [System.Drawing.Color]::FromArgb(110,110,110)
            Accent      = [System.Drawing.Color]::FromArgb(70,120,255)
            ButtonBack  = [System.Drawing.Color]::FromArgb(235,235,235)
            BorderColor = [System.Drawing.Color]::FromArgb(210,210,210)
            SectionBack = [System.Drawing.Color]::FromArgb(250,250,250)
        }
        "Gris" = @{
            BackColor   = [System.Drawing.Color]::FromArgb(232,232,236)
            PanelColor  = [System.Drawing.Color]::FromArgb(244,244,247)
            TextColor   = [System.Drawing.Color]::FromArgb(25,25,25)
            HintColor   = [System.Drawing.Color]::FromArgb(120,120,130)
            Accent      = [System.Drawing.Color]::FromArgb(64,96,180)
            ButtonBack  = [System.Drawing.Color]::FromArgb(220,220,225)
            BorderColor = [System.Drawing.Color]::FromArgb(200,200,205)
            SectionBack = [System.Drawing.Color]::FromArgb(248,248,250)
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

# Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Nuevo programa portable"
$form.Size = New-Object System.Drawing.Size(960,640)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'Sizable'
$form.MaximizeBox = $true
$form.MinimizeBox = $true
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$themes = Get-Themes
$currentTheme = $themes["Dark"]
$textColor = $currentTheme.TextColor
$hintColor = $currentTheme.HintColor

# Contenedor general (vertical)
$main = New-Object System.Windows.Forms.FlowLayoutPanel
$main.Dock = 'Fill'
$main.AutoScroll = $true
$main.WrapContents = $false
$main.FlowDirection = 'TopDown'
$main.Padding = '12,12,12,12'
$main.BackColor = $currentTheme.BackColor

$bold = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

# Panel de tema
$themePanel = New-Object System.Windows.Forms.FlowLayoutPanel
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
$main.Controls.Add($themePanel)

# Sección helper
function New-Section {
    param(
        [string]$Title,
        [System.Windows.Forms.Control[]]$Content
    )
    $grp = New-Object System.Windows.Forms.Panel
    $grp.Width = 900
    $grp.AutoSize = $true
    $grp.BorderStyle = 'FixedSingle'
    $grp.BackColor = $currentTheme.SectionBack
    $grp.Padding = '10,8,10,10'

    $titleLbl = New-Label -Text $Title -Font $bold -ForeColor $textColor
    $titleLbl.Margin = '0,0,0,6'
    $grp.Controls.Add($titleLbl)
    foreach ($c in $Content) {
        $c.Dock = 'Top'
        $grp.Controls.Add($c)
    }
    $grp.Controls.SetChildIndex($titleLbl,0)
    return $grp
}

# Campos principales (ejecutable y nombre)
$txtInstaller = New-TextBox -Text "" -Placeholder "Selecciona instalador .exe" -HintColor $hintColor -BackColor $currentTheme.PanelColor -TextColor $textColor
$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Examinar..."
$btnBrowse.FlatStyle = 'Flat'
$btnBrowse.BackColor = $currentTheme.ButtonBack
$btnBrowse.ForeColor = $textColor
$btnBrowse.Width = 110
$rowInstaller = New-Object System.Windows.Forms.TableLayoutPanel
$rowInstaller.ColumnCount = 2
$rowInstaller.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
$rowInstaller.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute', 120)))
$rowInstaller.AutoSize = $true
$rowInstaller.Controls.Add($txtInstaller,0,0)
$rowInstaller.Controls.Add($btnBrowse,1,0)
$rowInstaller.Margin = '0,0,0,6'

$lblInstallerDesc = New-Label -Text "Se copiara a installers/<ID>.exe" -ForeColor $hintColor
$installerSection = New-Section -Title "Instalador (.exe) a importar" -Content @($rowInstaller,$lblInstallerDesc)

$txtName = New-TextBox -Text "" -Placeholder "MiApp" -HintColor $hintColor -BackColor $currentTheme.PanelColor -TextColor $textColor
$lblNameDesc = New-Label -Text "Se usa como carpeta: apps/<ID> y data/<ID>." -ForeColor $hintColor
$nameSection = New-Section -Title "Nombre de la app (ID)" -Content @($txtName,$lblNameDesc)

# Sección flags y parámetros
$checksPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$checksPanel.AutoSize = $true
$checksPanel.FlowDirection = 'LeftToRight'
$checksPanel.WrapContents = $true
$checksPanel.Margin = '0,0,0,5'

function New-Check($text, [bool]$state) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $text
    $cb.Checked = $state
    $cb.AutoSize = $true
    $cb.Margin = '0,0,10,5'
    $cb.ForeColor = $textColor
    return $cb
}

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

$txtArgs = New-TextBox -Text "" -Placeholder "Extra args (opcional)" -HintColor $hintColor -BackColor $currentTheme.PanelColor -TextColor $textColor
$lblArgsDesc = New-Label -Text "Se agregaran después de las opciones marcadas. Tokens: {BIN}, {APPROOT}, {DATA}, {ROAMING}, {LOCAL}, {PROGRAMDATA}, {USERPROFILE}" -ForeColor $hintColor
$flagsSection = New-Section -Title "Flags y parámetros" -Content @($checksPanel,$txtArgs,$lblArgsDesc)

# Sección avanzada
$advancedPanel = New-Object System.Windows.Forms.TableLayoutPanel
$advancedPanel.ColumnCount = 2
$advancedPanel.RowCount = 4
$advancedPanel.AutoSize = $true
$advancedPanel.Dock = 'Top'
$advancedPanel.Margin = '0,0,0,5'
$advancedPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute',160)))
$advancedPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent',100)))

function Add-AdvancedRow($label,$control) {
    $r = $advancedPanel.RowCount - 1
    $lbl = New-Label -Text $label -ForeColor $hintColor
    $advancedPanel.Controls.Add($lbl,0,$r)
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

$infoFlags = New-Label -Text "Recomendadas ya marcadas. Avanzadas (LANG/TASKS/COMPONENTS/LOADINF/SAVEINF) solo si el instalador las soporta. /ALLUSERS o /CURRENTUSER según se requiera; /NOICONS y /MERGETASKS para evitar accesos directos; /NOCANCEL y /NOCLOSEAPPLICATIONS para bloquear intervención; /CLOSEAPPLICATIONS /FORCECLOSEAPPLICATIONS reinician procesos: úsalo con cautela." -ForeColor $hintColor
$infoFlags.MaximumSize = New-Object System.Drawing.Size(880,0)
$advancedSection = New-Section -Title "Opciones avanzadas" -Content @($infoFlags,$advancedPanel)

# Ejecutable/WD
$txtExe = New-TextBox -Text "" -Placeholder "apps\\MiApp\\bin\\MiApp.exe" -HintColor $hintColor -BackColor $currentTheme.PanelColor -TextColor $textColor
$lblExeDesc = New-Label -Text "Ejemplo: apps\\MiApp\\bin\\MiApp.exe" -ForeColor $hintColor
$exeSection = New-Section -Title "Ejecutable relativo tras instalar" -Content @($txtExe,$lblExeDesc)

$txtWD = New-TextBox -Text "" -Placeholder "apps\\MiApp\\bin" -HintColor $hintColor -BackColor $currentTheme.PanelColor -TextColor $textColor
$lblWDDesc = New-Label -Text "Por defecto, la carpeta del ejecutable." -ForeColor $hintColor
$wdSection = New-Section -Title "WorkingDir relativo (opcional)" -Content @($txtWD,$lblWDDesc)

# Agregar secciones en orden: instalador y nombre primeros
$main.Controls.Add($installerSection)
$main.Controls.Add($nameSection)
$main.Controls.Add($flagsSection)
$main.Controls.Add($advancedSection)
$main.Controls.Add($exeSection)
$main.Controls.Add($wdSection)

# Botones inferiores
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Iniciar instalacion portable"
$btnStart.Width = 210
$btnStart.Height = 34
$btnStart.FlatStyle = 'Flat'
$btnStart.BackColor = $currentTheme.Accent
$btnStart.ForeColor = [System.Drawing.Color]::White
$btnStart.Font = $bold

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancelar"
$btnCancel.Width = 110
$btnCancel.Height = 34
$btnCancel.FlatStyle = 'Flat'
$btnCancel.BackColor = $currentTheme.ButtonBack
$btnCancel.ForeColor = $textColor

$buttons = New-Object System.Windows.Forms.FlowLayoutPanel
$buttons.FlowDirection = 'RightToLeft'
$buttons.Dock = 'Bottom'
$buttons.Height = 60
$buttons.Padding = '0,10,10,10'
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
    foreach ($ctrl in $main.Controls) {
        if ($ctrl -is [System.Windows.Forms.Panel]) {
            $ctrl.BackColor = $t.SectionBack
            foreach ($c in $ctrl.Controls) {
                if ($c -is [System.Windows.Forms.Label]) {
                    if ($c.Font.Bold) { $c.ForeColor = $t.TextColor } else { $c.ForeColor = $t.HintColor }
                }
                if ($c -is [System.Windows.Forms.TextBox]) {
                    $c.BackColor = $t.PanelColor
                    if ($c.ForeColor -ne $hintColor) { $c.ForeColor = $t.TextColor }
                }
                if ($c -is [System.Windows.Forms.CheckBox]) {
                    $c.ForeColor = $t.TextColor
                }
                if ($c -is [System.Windows.Forms.TableLayoutPanel] -or $c -is [System.Windows.Forms.FlowLayoutPanel]) {
                    $c.BackColor = $t.SectionBack
                    foreach ($inner in $c.Controls) {
                        if ($inner -is [System.Windows.Forms.TextBox]) {
                            $inner.BackColor = $t.PanelColor
                            if ($inner.ForeColor -ne $hintColor) { $inner.ForeColor = $t.TextColor }
                        }
                        if ($inner -is [System.Windows.Forms.Label]) {
                            if ($inner.Font.Bold) { $inner.ForeColor = $t.TextColor } else { $inner.ForeColor = $t.HintColor }
                        }
                        if ($inner -is [System.Windows.Forms.CheckBox]) {
                            $inner.ForeColor = $t.TextColor
                        }
                        if ($inner -is [System.Windows.Forms.Button]) {
                            $inner.BackColor = $t.ButtonBack
                            $inner.ForeColor = $t.TextColor
                        }
                    }
                }
            }
        }
    }
    $btnStart.BackColor = $t.Accent
    $btnStart.ForeColor = [System.Drawing.Color]::White
    $btnCancel.BackColor = $t.ButtonBack
    $btnCancel.ForeColor = $t.TextColor
    $cmbTheme.BackColor = $t.PanelColor
    $cmbTheme.ForeColor = $t.TextColor
    $themePanel.BackColor = $t.BackColor
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

Apply-Theme -name $cmbTheme.SelectedItem

[void]$form.ShowDialog()
