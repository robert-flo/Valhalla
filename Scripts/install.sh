#!/usr/bin/env bash
# shellcheck disable=SC2154
#|---/ /+--------------------------+---/ /|#
#|--/ /-| Main installation script |--/ /-|#
#|-/ /--| Roberto Flores           |-/ /--|#
#|/ /---+--------------------------+/ /---|#

cat << "EOF"

-----------------------------------------------------------
        .
       / \       _     ___   __ _ __   __ _   _
      /^  \    _| |_  | _ \ / _` |\ \ / /| \ | |
     /  _  \  |_   _| ||  /| (_| | \ V / |  \| |
    /  | | ~\   |_|   |_|_\ \__,_|  \_/  |_| \_|
   /.-'   '-.\

-----------------------------------------------------------

EOF

#--------------------------------#
# import variables and functions #
#--------------------------------#
# Establece el directorio de trabajo del script e importa variables y funciones globales
# desde global_fn.sh. Si no se puede cargar el archivo, el script termina con error.
scrDir="$(dirname "$(realpath "$0")")"
# shellcheck disable=SC1091
if ! source "${scrDir}/global_fn.sh"; then
  echo "Error: unable to source global_fn.sh..."
  exit 1
fi

#------------------#
# evaluate options #
#------------------#
# Inicialización y Evaluación de Opciones (Líneas 33-88)
# El script define una serie de banderas (flags) por defecto:
#
# flg_Install=0      : Instalar Hyprland sin configuraciones.
# flg_Restore=0      : Restaurar archivos de configuración.
# flg_Service=0      : Habilitar servicios del sistema.
# flg_DryRun=0       : Modo simulación (test run) sin ejecutar cambios.
# flg_Shell=0        : Revaluar la configuración de la Shell.
# flg_Nvidia=1       : Por defecto se asume soporte para GPUs Nvidia (acciones de Nvidia activadas).
# flg_ThemeInstall=1 : Reinstalaciones de temas activadas.
flg_Install=0
flg_Restore=0
flg_Service=0
flg_DryRun=0
flg_Shell=0
flg_Nvidia=1
flg_ThemeInstall=1
flg_Overwrite=0

# A continuación, recorre los argumentos pasados por la línea de comandos usando un ciclo:
# while getopts idrstmnho RunStep; do:
#
# -i : Activa la instalación (flg_Install=1).
# -d : Activa la instalación y define use_default="--noconfirm" para proceder sin confirmación del usuario.
# -r : Activa la restauración de configuraciones (flg_Restore=1).
# -s : Habilita los servicios del sistema (flg_Service=1).
# -n : Desactiva el soporte Nvidia (flg_Nvidia=0) e imprime un aviso en consola.
# -h : Activa la reevaluación de la shell (flg_Shell=1) y lo registra.
# -t : Activa el modo simulación (flg_DryRun=1).
# -m : Desactiva la reinstalación de temas (flg_ThemeInstall=0).
# -o : Fuerza la sobreescritura de los archivos de destino (flg_Overwrite=1).
# Cualquier otra opción: Muestra un menú de ayuda (Usage) detallando las opciones disponibles
# y las combinaciones correctas de argumentos, y finaliza el script con código de salida 1.
while getopts idrstmnho RunStep; do
  case $RunStep in
    i) flg_Install=1 ;;
    d)
      flg_Install=1
      export use_default="--noconfirm"
      ;;
    r) flg_Restore=1 ;;
    s) flg_Service=1 ;;
    n)
      # shellcheck disable=SC2034
      export flg_Nvidia=0
      print_log -r "[nvidia] " -b "Ignored :: " "skipping Nvidia actions"
      ;;
    h)
      # shellcheck disable=SC2034
      export flg_Shell=1
      print_log -r "[shell] " -b "Reevaluate :: " "shell options"
      ;;
    t) flg_DryRun=1 ;;
    m) flg_ThemeInstall=0 ;;
    o) flg_Overwrite=1 ;;
    *)
      cat << EOF
Usage: $0 [options]
            i : [i]nstall hyprland without configs
            d : install hyprland [d]efaults without configs --noconfirm
            r : [r]estore config files
            s : enable system [s]ervices
            n : ignore/[n]o [n]nvidia actions (-irsn to ignore nvidia)
            h : re-evaluate S[h]ell
            m : no the[m]e reinstallations
            t : [t]est run without executing (-irst to dry run all)
            o : [o]verwrite target files always

NOTE:
        running without args is equivalent to -irs
        to ignore nvidia, run -irsn

WRONG:
        install.sh -n # This will not work

EOF
      exit 1
      ;;
  esac
done

# Define la variable RAVN_LOG con la marca de tiempo actual y exporta las banderas
# de configuración y log para que estén disponibles en subprocesos externos.
RAVN_LOG="$(date +'%y%m%d_%Hh%Mm%Ss')"
export flg_DryRun flg_Nvidia flg_Shell flg_Install flg_ThemeInstall RAVN_LOG flg_Overwrite

# Define la función de limpieza al salir del script para detener el keepalive de sudo
# y resguardar la lista de paquetes de instalación en el directorio de logs.
cleanup() {
  if [[ -n $SUDO_KEEPALIVE_PID ]]; then
    kill "$SUDO_KEEPALIVE_PID" 2> /dev/null || true
  fi

  if [[ -f $scrDir/install_pkg.lst ]]; then
    mkdir -p "$cacheDir/logs/$RAVN_LOG"
    mv "$scrDir/install_pkg.lst" "$cacheDir/logs/$RAVN_LOG/install_pkg.lst" 2> /dev/null || true
  fi
}
trap cleanup EXIT

# Gestiona el comportamiento de ejecución basándose en los argumentos provistos:
# - Si se especificó el modo de prueba (dry-run), se imprime un mensaje de estado.
# - Si el script se ejecutó sin ningún argumento (OPTIND=1), se habilitan por
#   defecto los procesos de instalación, restauración y activación de servicios.
if [ "${flg_DryRun}" -eq 1 ]; then
  print_log -n "[test-run] " -b "enabled :: " "Testing without executing"
fi

if [ "${flg_Overwrite}" -eq 1 ]; then
  print_log -y "[overwrite] " -b "enabled :: " "Always overwriting target files"
fi

if [ $OPTIND -eq 1 ]; then
  flg_Install=1
  flg_Restore=1
  flg_Service=1
fi

#-----------------------#
# sudo session keepalive #
#-----------------------#
# Si no es un dry-run, solicita la contraseña una vez al inicio
# y mantiene activa la credencial en segundo plano.
if ((flg_DryRun == 0)); then
  print_log -c "Sudo :: " "Validando credenciales para la instalación..."
  sudo -v
  while true; do
                 sudo -n true
                               sleep 60
  done                                        2> /dev/null &
  SUDO_KEEPALIVE_PID=$!
fi

#--------------------#
# pre-install script #
#--------------------#
# Si las banderas de instalación (flg_Install) y de restauración de configuraciones (flg_Restore)
# están activadas (ambas en 1), se imprime un banner informativo en arte ASCII ("pre-install")
# y se ejecuta el script preparatorio install_pre.sh ubicado en el directorio del script.
if [ ${flg_Install} -eq 1 ] && [ ${flg_Restore} -eq 1 ]; then
  cat << "EOF"
                _         _       _ _
 ___ ___ ___   |_|___ ___| |_ ___| | |
| . |  _| -_|  | |   |_ -|  _| .'| | |
|  _|_| |___|  |_|_|_|___|_| |__,|_|_|
|_|

EOF

  "${scrDir}/install_pre.sh"
fi

#------------#
# installing #
#------------#
# Si la bandera de instalación (flg_Install) está activada (en 1), se inicia el proceso principal:
# 1. Se muestra en consola el banner en arte ASCII de "installing".
# 2. Se procede a la preparación y compilación de la lista final de paquetes a instalar.
if [ ${flg_Install} -eq 1 ]; then
  cat << "EOF"

 _         _       _ _ _
|_|___ ___| |_ ___| | |_|___ ___
| |   |_ -|  _| .'| | | |   | . |
|_|_|_|___|_| |__,|_|_|_|_|_|_  |
                            |___|

EOF

  #----------------------#
  # prepare package list #
  #----------------------#
  # Desplaza los argumentos posicionales de la línea de comandos para capturar el archivo
  # de paquetes personalizados proveído por el usuario como primer argumento no-opción.
  # Copia la plantilla base de paquetes (pkg_core.lst) al archivo temporal de instalación,
  # define una trampa (trap) para resguardar la lista procesada en los logs al finalizar,
  # y añade al final de la lista los paquetes personalizados si se proporciona un archivo válido.
  shift $((OPTIND - 1))
  custom_pkg=$1
  cp "${scrDir}/pkg_core.lst" "${scrDir}/install_pkg.lst"

  # Asegura la existencia del directorio de logs de la sesión.
  mkdir -p "${cacheDir}/logs/${RAVN_LOG}"

  echo -e "\n#user packages" >> "${scrDir}/install_pkg.lst" # Add a marker for user packages
  if [ -f "${custom_pkg}" ] && [ -n "${custom_pkg}" ]; then
    cat "${custom_pkg}" >> "${scrDir}/install_pkg.lst"
  fi

  #--------------------------------#
  # add nvidia drivers to the list #
  #--------------------------------#
  # Si se detecta una GPU Nvidia en el sistema y no se especificó ignorar la instalación (flg_Nvidia=1):
  # 1. Se leen las bases de paquetes de kernel en /usr/lib/modules/*/pkgbase para añadir
  #    los correspondientes paquetes de cabecera (-headers) a la lista.
  # 2. Se añaden los controladores y utilidades Nvidia recomendados (nvidia_detect --drivers).
  # Si se detecta la GPU pero se especificó ignorarla (flg_Nvidia=0), se emite una advertencia.
  # Finalmente, se listan en consola con formato detallado las GPUs encontradas en el sistema.
  if nvidia_detect; then
    if [ ${flg_Nvidia} -eq 1 ]; then
      cat /usr/lib/modules/*/pkgbase | while read -r kernel; do
        echo "${kernel}-headers" >> "${scrDir}/install_pkg.lst"
      done
      nvidia_detect --drivers >> "${scrDir}/install_pkg.lst"
    else
      print_log -warn "Nvidia" "Nvidia GPU detected but ignored..."
    fi
  fi
  nvidia_detect --verbose

  #----------------#
  # get user prefs #
  #----------------#
  # Selección de preferencias del usuario:
  # 1. Comprueba si hay algún ayudante de AUR instalado. Si no se encuentra ninguno, muestra
  #    un menú interactivo con temporizador para elegir e instalar uno (default: yay-bin).
  # 2. Comprueba si hay alguna shell compatible instalada (zsh o fish). Si no, muestra un menú
  #    para elegir una, la añade a la lista de instalación y la configura.
  # 3. Valida la presencia de la cabecera de paquetes de usuario en la lista de instalación.
  echo ""
  if ! chk_list "aurhlpr" "${aurList[@]}"; then
    print_log -c "\nAUR Helpers :: "
    aurList+=("yay-bin" "paru-bin") # Add this here instead of in global_fn.sh
    for i in "${!aurList[@]}"; do
      print_log -sec "$((i + 1))" " ${aurList[$i]} "
    done

    prompt_timer 120 "Enter option number [default: yay-bin] | q to quit "

    case "${PROMPT_INPUT}" in
      1) export getAur="yay" ;;
      2) export getAur="paru" ;;
      3) export getAur="yay-bin" ;;
      4) export getAur="paru-bin" ;;
      q)
        print_log -sec "AUR" -crit "Quit" "Exiting..."
        exit 1
        ;;
      *)
        print_log -sec "AUR" -warn "Defaulting to yay-bin"
        print_log -sec "AUR" -stat "default" "yay-bin"
        export getAur="yay-bin"
        ;;
    esac
    if [[ -z "$getAur" ]]; then
      print_log -sec "AUR" -crit "No AUR helper found..." "Log file at ${cacheDir}/logs/${RAVN_LOG}"
      exit 1
    fi
  fi

  if ! chk_list "myShell" "${shlList[@]}"; then
    print_log -c "Shell :: "
    for i in "${!shlList[@]}"; do
      print_log -sec "$((i + 1))" " ${shlList[$i]} "
    done
    prompt_timer 120 "Enter option number [default: zsh] | q to quit "

    case "${PROMPT_INPUT}" in
      1) export myShell="zsh" ;;
      2) export myShell="fish" ;;
      q)
        print_log -sec "shell" -crit "Quit" "Exiting..."
        exit 1
        ;;
      *)
        print_log -sec "shell" -warn "Defaulting to zsh"
        export myShell="zsh"
        ;;
    esac
    print_log -sec "shell" -stat "Added as shell" "${myShell}"
    echo "${myShell}" >> "${scrDir}/install_pkg.lst"

    if [[ -z "$myShell" ]]; then
      print_log -sec "shell" -crit "No shell found..." "Log file at ${cacheDir}/logs/${RAVN_LOG}"
      exit 1
    else
      print_log -sec "shell" -stat "detected :: " "${myShell}"
    fi
  fi

  if ! grep -q "^#user packages" "${scrDir}/install_pkg.lst"; then
    print_log -sec "pkg" -crit "No user packages found..." "Log file at ${cacheDir}/logs/${RAVN_LOG}/install.sh"
    exit 1
  fi

  #--------------------------------#
  # Omarchy repository (early setup) #
  #--------------------------------#
  # Configure the [omarchy] repository before package installation so that
  # Omarchy packages can be resolved during the main install phase.
  RAVN_DIR="${scrDir}/ravn"
  export RAVN_DIR
  # shellcheck disable=SC1091
  source "${RAVN_DIR}/lib/omarchy.sh"
  if ! omarchy_repo_is_configured; then
    print_log -g "[OMARCHY] " -b " :: " "Configuring Omarchy repository before package install..."
    setup_omarchy_repo
  else
    print_log -g "[OMARCHY] " -b " :: " "Repository already configured"
  fi

  #--------------------------------#
  # install packages from the list #
  #--------------------------------#
  "${scrDir}/install_pkg.sh" "${scrDir}/install_pkg.lst"
fi

#---------------------------#
# restore my custom configs #
#---------------------------#
# Proceso de restauración de configuraciones personalizadas del usuario:
# 1. Si la bandera flg_Restore está activa (en 1), se muestra en consola el banner ASCII de "restore".
# 2. Si Hyprland está ejecutándose (HYPRLAND_INSTANCE_SIGNATURE activo) y no es modo de prueba (dry-run),
#    desactiva temporalmente el autoreload de configuraciones de Hyprland para evitar parpadeos y cargas innecesarias.
# 3. Invoca consecutivamente a los scripts de restauración: fuentes (restore_fnt.sh),
#    configuraciones (restore_cfg.sh) y temas (restore_thm.sh).
# 4. Genera la caché de fondos de pantalla (wallpapers), inicializa el tema visual y recarga la barra
#    Waybar exportando temporalmente la ruta de utilidades del sistema en el PATH (si no es modo de prueba).
if [ ${flg_Restore} -eq 1 ]; then
  cat << "EOF"

             _           _
 ___ ___ ___| |_ ___ ___|_|___ ___
|  _| -_|_ -|  _| . |  _| |   | . |
|_| |___|___|_| |___|_| |_|_|_|_  |
                              |___|

EOF

  if [ "${flg_DryRun}" -ne 1 ] && [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    hyprctl keyword misc:disable_autoreload 1 -q
  fi

  "${scrDir}/restore_fnt.sh"
  "${scrDir}/restore_cfg.sh"
  "${scrDir}/restore_thm.sh"
  print_log -g "[generate] " "cache ::" "Wallpapers..."
  if [ "${flg_DryRun}" -ne 1 ]; then
    for p in "$HOME/.local/lib/hyde" "$HOME/.local/bin"; do
      case ":$PATH:" in
        *":$p:"*) ;;
        *) export PATH="$p:$PATH" ;;
      esac
    done
    "$HOME/.local/lib/hyde/wallpaper/cache.sh" commence -t ""
    "$HOME/.local/lib/hyde/theme.switch.sh" -q || true
    "$HOME/.local/lib/hyde/waybar.py" --update || true
    echo "[install] reload :: Hyprland"
  fi

  # Inicialización de dotbare para rastreo selectivo
  if [ -f "${scrDir}/dotbare_init.sh" ]; then
    print_log -g "[dotbare]" -b " :: " "Configurando seguimiento selectivo de dotfiles..."
    bash "${scrDir}/dotbare_init.sh"
  fi

  # Bootstrap Studium Emacs (elpaca) after configs are restored
  if [ -f "${scrDir}/install_emacs.sh" ]; then
    cat << "EOF"

 _____ __  __    _    ___ _        _
| ____|  \/  |  / \  |_ _| |      / \
|  _| | |\/| | / _ \  | || |     / _ \
| |___| |  | |/ ___ \ | || |___ / ___ \
|_____|_|  |_/_/   \_\___|_____/_/   \_\

EOF

    if [ "${flg_DryRun}" -eq 1 ]; then
      print_log -n "[emacs] " -b "dry-run :: " "Would run ${scrDir}/install_emacs.sh"
    else
      print_log -g "[emacs] " -b " :: " "Bootstrapping Studium Emacs..."
      bash "${scrDir}/install_emacs.sh"
    fi
  fi

fi

# ==============================================================================
# Ejecución del script de post-instalación
# ==============================================================================
# Si las banderas de instalación (${flg_Install}) y restauración (${flg_Restore})
# están activas (valor igual a 1), se imprime un banner de éxito ("post install")
# en la consola y se ejecuta el script secundario "install_pst.sh".
if [ ${flg_Install} -eq 1 ] && [ ${flg_Restore} -eq 1 ]; then
  cat << "EOF"

             _      _         _       _ _
 ___ ___ ___| |_   |_|___ ___| |_ ___| | |
| . | . |_ -|  _|  | |   |_ -|  _| .'| | |
|  _|___|___|_|    |_|_|_|___|_| |__,|_|_|
|_|

EOF

  "${scrDir}/install_pst.sh"
fi

# ==============================================================================
# Ejecución de migraciones de configuración (RaVN Migrations)
# ==============================================================================
# Si la bandera de restauración (${flg_Restore}) está activa, este bloque:
# 1. Establece y verifica la ruta del directorio de migraciones.
# 2. Busca el archivo de migración más reciente ordenado en orden descendente.
# 3. Si encuentra un archivo válido, procede a ejecutarlo usando 'sh'.
# 4. Maneja de manera segura los fallos en la migración registrando una advertencia.
if [ ${flg_Restore} -eq 1 ]; then

  # migrationDir="$(realpath "$(dirname "$(realpath "$0")")/../migrations")"
  migrationDir="${scrDir}/migrations"

  if [ ! -d "${migrationDir}" ]; then
    print_log -warn "Migrations" "Directory not found: ${migrationDir}"
  fi

  echo "Running migrations from: ${migrationDir}"

  if [ -d "${migrationDir}" ] && find "${migrationDir}" -type f | grep -q .; then
    migrationFile=$(find "${migrationDir}" -maxdepth 1 -type f -printf '%f\n' | sort -r | head -n 1)

    if [[ -n "${migrationFile}" && -f "${migrationDir}/${migrationFile}" ]]; then
      echo "Found migration file: ${migrationFile}"
      sh "${migrationDir}/${migrationFile}" || { true && print_log -warn "Migration" "Failed to execute ${migrationFile}"; }
    else
      echo "No migration file found in ${migrationDir}. Skipping migrations."
    fi
  fi

fi

# ==============================================================================
# Habilitación y restauración de servicios del sistema (System Services)
# ==============================================================================
# Si la bandera de servicios (${flg_Service}) está activa (igual a 1), se muestra
# un banner y se ejecuta el script secundario "restore_svc.sh".
if [ ${flg_Service} -eq 1 ]; then
  cat << "EOF"

                 _
 ___ ___ ___ _ _|_|___ ___ ___
|_ -| -_|  _| | | |  _| -_|_ -|
|___|___|_|  \_/|_|___|___|___|

EOF

  "${scrDir}/restore_svc.sh"
fi

# ==============================================================================
# Configuracion Final (Final Tweaks & Custom Installs)
# ==============================================================================
# Si las banderas de instalación (${flg_Install}) y restauración (${flg_Restore})
# están activas (valor igual a 1), se imprime un banner, se ejecutan los
# instaladores personalizados y finalmente se ejecuta "install_fnl.sh".
if ((flg_Install == 1))   && ((flg_Restore == 1)); then
  cat << "EOF"

  _ _             _
 |  _|_|___ ___ _| |
 |  _| |   | .'| . |
 |_| |_|_|_|__,|___|

EOF

  "${scrDir}/ravn/setup.sh"
fi

# ==============================================================================
# Desktop launchers (webapps + TUIs)
# ==============================================================================
if [ ${flg_Restore} -eq 1 ] && [ -f "${scrDir}/launchers/install_launchers.sh" ]; then
  cat << "EOF"

 _                       _                _
| |    ___  __ _  __ _ (_)_ __ ___  __ _| |
| |   / _ \/ _` |/ _` || | '_ ` _ \/ _` | |
| |__|  __/ (_| | (_| || | | | | | | (_| | |
|_____\___|\__, |\__,_|/ |_| |_| |_|\__,_|_|
           |___/

EOF

  if [ "${flg_DryRun}" -eq 1 ]; then
    print_log -n "[launchers] " -b "dry-run :: " "Would run ${scrDir}/launchers/install_launchers.sh"
  else
    print_log -g "[launchers] " -b " :: " "Installing webapps and TUIs..."
    bash "${scrDir}/launchers/install_launchers.sh"
  fi
fi

# ==============================================================================
# Finalización de la instalación y registro de logs
# ==============================================================================
if [ $flg_Install -eq 1 ]; then
  echo ""
  print_log -g "Installation" " :: " "COMPLETED!"
fi
print_log -b "Log" " :: " -y "View logs at ${cacheDir}/logs/${RAVN_LOG}"

# ==============================================================================
# Solicitud interactiva de reinicio del sistema
# ==============================================================================
# Si se realizó alguna acción y no estamos en modo dry-run, se sugiere reiniciar
# el sistema para aplicar los cambios del entorno de escritorio RaVN correctamente.
if [ $flg_Install -eq 1 ] ||
  [ $flg_Restore -eq 1 ] ||
  [ $flg_Service -eq 1 ] &&
  [ $flg_DryRun -ne 1 ]; then

  if [[ -z "${HYPRLAND_CONFIG:-}" ]] || [[ ! -f "${HYPRLAND_CONFIG}" ]]; then
    print_log -warn "Hyprland config not found! Might be a new install or upgrade."
    print_log -warn "Please reboot the system to apply new changes."
  fi

  print_log -stat "RaVN" "It is not recommended to use newly installed or upgraded RaVN without rebooting the system. Do you want to reboot the system? (y/N)"
  read -r answer

  if [[ "$answer" == [Yy] ]]; then
    echo "Rebooting system"
    systemctl reboot
  else
    echo "The system will not reboot"
  fi
fi
