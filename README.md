# Programas autocontenidos en una carpeta (Windows)

Este repo agrupa aplicaciones Windows en modo "portable": binarios, datos y configuraciones dentro de la misma carpeta, para moverlas a otra PC o una USB. Incluye scripts para rehidratar (reinstalar servicios/drivers cuando aplica), lanzar apps con APPDATA/LOCALAPPDATA/PROGRAMDATA/TEMP redirigidos al repo, diagnósticos y backups.

## Cómo funciona
- Los procesos hijos se lanzan con variables de entorno apuntando a subcarpetas locales: `APPDATA`, `LOCALAPPDATA`, `PROGRAMDATA`, `TEMP/TMP`, `USERPROFILE`. Todo queda en `data/<App>`.
- Los binarios de cada app viven en `apps/<App>/bin`.
- Servicios/drivers (ej. VPN) se reinstalan con el instalador original usando `/DIR={BIN}`; esto se automatiza con los scripts.
- Tokens DPAPI no son portables entre equipos: en una nueva PC tendrás que iniciar sesión una vez en cada app que use autenticación ligada al equipo/usuario.
- Wizard para nuevas apps: `new_portable_app_wizard.bat` abre un formulario, permite elegir el instalador, configurar nombre y args, actualiza el catálogo y ejecuta la instalación portable automáticamente.

## Estructura
```
apps/                 Binarios por app (ej. apps/ProtonVPN/bin)
data/                 Datos/config por app (APPDATA/LOCALAPPDATA/PROGRAMDATA/USERPROFILE/TEMP redirigidos)
installers/           Instaladores originales (LFS si pesan >100 MB)
portable.ps1          Funciones base (Start-PortableApp, Install-PortableApp, etc.)
portable-apps.json    Catálogo de apps (installer, args, ejecutable, paths esperados)
rehydrate-all.ps1     Reinstala/rehidrata todas o una app según el catálogo
rehydrate-and-launch-protonvpn.ps1  Rehidratado específico para ProtonVPN
launch_protonvpn_portable.bat/.ps1  Lanzan Proton VPN en sandbox portable
install_protonvpn_portable.bat/.ps1 Reinstalan Proton VPN (drivers/servicio)
portable-diagnose.ps1 Diagnóstico de rutas y fugas por app usando catálogo
portable-backup.ps1   Backup/restore de data/<App> en zip
enable_long_paths.bat/.ps1 Habilitan rutas largas (LongPathsEnabled=1) en Windows
new-portable-app.ps1 / new_portable_app_wizard.bat Wizard GUI para agregar apps al catálogo y rehidratarlas
.tools/git            Git portátil para este repo (ignorado en .gitignore)
```

## Uso rápido en una PC nueva
1) (Opcional) Habilitar rutas largas si al descomprimir hay "Path too long": doble clic `enable_long_paths.bat` y reinicia sesión/PC.
2) Descomprime el repo en una ruta corta (ej. `C:\pvpn\`).
3) Rehidratar todo el catálogo (reinstalar servicios y binarios):
   ```powershell
   powershell -ExecutionPolicy Bypass -File rehydrate-all.ps1 -Launch
   ```
   - Para una sola app: `... -AppName ProtonVPN`
   - `-SkipMissing` para saltar instaladores faltantes.
4) Lanzar Proton VPN (si no usaste `-Launch`):
   - Doble clic `launch_protonvpn_portable.bat`
5) Inicia sesión en Proton VPN (y en otras apps que lo requieran). El login puede pedirse de nuevo en cada PC por DPAPI.

## Añadir un programa nuevo (modo manual)
1) Coloca el instalador en `installers/`.
2) Edita `portable-apps.json` y añade un bloque copiando el de `TemplateApp`, ajustando:
   - `name`: identificador de la app.
   - `installer`: ruta relativa al repo en `installers/...`
   - `installerArgs`: usa tokens `{BIN}`, `{APPROOT}`, `{DATA}`, `{ROAMING}`, `{LOCAL}`, `{PROGRAMDATA}`, `{USERPROFILE}`; típico `/DIR="{BIN}" /S` o similar.
   - `executable`: ruta relativa al ejecutable en `apps/<App>/bin/...`
   - `workingDir`: carpeta de trabajo (normalmente donde está el exe).
   - `dataPaths`: rutas bajo `data/<App>/...` (ya vienen prellenadas).
   - `knownExternalPaths`: patrones a vigilar fuera del repo (ej. `%APPDATA%/MiApp*`).
3) Rehidrata la nueva app:
   ```powershell
   powershell -ExecutionPolicy Bypass -File rehydrate-all.ps1 -AppName "MiApp" -Launch
   ```
4) Verifica fugas/datos:
   ```powershell
   powershell -ExecutionPolicy Bypass -File portable-diagnose.ps1 -AppName "MiApp"
   ```
5) Si la app requiere servicios/drivers, documenta en `notes` y espera re-login en cada PC.

### Wizard (modo fácil, GUI)
- Doble clic `new_portable_app_wizard.bat`.
- Llena:
  - Nombre de la app (ID).
  - Instalador (Examinar).
  - Parámetros (default `/DIR="{BIN}" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART`).
  - Ejecutable relativo (p. ej. `apps\<App>\bin\MiApp.exe`).
  - WorkingDir (opcional, por defecto la carpeta del exe).
- El wizard copia el instalador a `installers/`, actualiza `portable-apps.json`, y ejecuta `rehydrate-all.ps1 -AppName <App> -Launch`.

## Scripts clave
- `rehydrate-all.ps1`: lee `portable-apps.json` y ejecuta Install-PortableApp; opcionalmente lanza la app (`-Launch`). Usa `-AppName` para filtrar y `-SkipMissing` para no fallar si falta el instalador.
- `portable-diagnose.ps1`: valida que APPDATA/LOCALAPPDATA/PROGRAMDATA/TEMP estén en el repo y revisa fugas según `knownExternalPaths` del catálogo.
- `portable-backup.ps1`:
  - Backup: `... -Mode backup -AppName ProtonVPN -ArchivePath backups/protonvpn.zip`
  - Restore: `... -Mode restore -AppName ProtonVPN -ArchivePath backups/protonvpn.zip`
- `enable_long_paths.bat`: habilita LongPathsEnabled=1 (admin), reinicia la sesión/PC.
- Proton específico: `install_protonvpn_portable.bat` (rehidrata drivers/servicio) y `launch_protonvpn_portable.bat` (lanza en sandbox).

## Beneficios
- Todo en una sola carpeta: binarios, datos, logs, accesos directos.
- Rehidratación reproducible tras mover el repo a otra PC.
- Diagnósticos de fugas para mantener el aislamiento.
- Backups portables por app.

## Limitaciones
- Tokens y credenciales protegidos con DPAPI no son portables entre equipos: se requerirá inicio de sesión en cada PC para apps que usen estos mecanismos (ej. Proton VPN, navegadores con perfiles cifrados, SSO empresarial).
- Servicios/drivers deben reinstalarse en cada PC (scripts ya lo automatizan).
- Algunas apps no respetan APPDATA/LOCALAPPDATA y pueden escribir en rutas absolutas o HKLM; revisa `portable-diagnose` para detectarlas.
- GitHub limita archivos >100 MB; se usa Git LFS para instaladores grandes.

## Flujo recomendado para el equipo
1) Mantener el catálogo `portable-apps.json` al día (instalador, args, exe).
2) Al preparar una “versión buena” de la carpeta: rehidrata, configura, inicia sesión en apps que lo permitan, y ejecuta `portable-diagnose` para confirmar que no hay fugas.
3) Empaqueta o haz push (con LFS) y comparte la carpeta.
4) En cada PC destino: habilita long paths si hace falta, descomprime en ruta corta, ejecuta `rehydrate-all.ps1 -Launch`, y reautentica apps que lo requieran.
