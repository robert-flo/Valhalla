# Issue 66 — Guía de verificación manual

Esta guía verifica manualmente el instalador progresivo de RaVN en `master`.
No sustituye los tests automatizados: su objetivo es comprobar el flujo visible
para una persona usuaria y confirmar que las categorías no interfieren entre sí.

## 1. Preparación

Ejecuta las pruebas desde una copia limpia de `master`:

```bash
cd /home/ragnarok/Work/Valhalla/master
git status --short --branch
git pull --ff-only
```

El primer comando debe mostrar un working tree limpio. Guarda el hash usado:

```bash
git rev-parse HEAD
```

Revisa la ayuda y los permisos:

```bash
bash Scripts/install_ravn.sh --help
test -x Scripts/install_ravn.sh || chmod +x Scripts/install_ravn.sh
```

No ejecutes el instalador como root. Para las pruebas que escriben archivos,
usa un usuario normal y un `HOME` temporal. Antes de continuar, confirma que
el directorio temporal no contiene datos importantes:

```bash
TEST_HOME="$(mktemp -d)"
export TEST_HOME
trap 'rm -rf "$TEST_HOME"' EXIT
```

## 2. Menú principal y categorías

Inicia el menú con `HOME` temporal:

```bash
HOME="$TEST_HOME" bash Scripts/install_ravn.sh
```

Comprueba manualmente:

1. Aparecen `Desktop launchers`, `Binaries`, `Configurations`, `Applications`
   e `Install everything`.
2. `q` termina el programa con un mensaje de despedida.
3. Cada categoría abre un submenú con `Install everything`, `Run tests`,
   `Clean installed` y `Back`.
4. Una opción inválida muestra un error y vuelve a pedir selección.
5. En una categoría no disponible, cualquiera de sus acciones informa que no
   está disponible y no crea archivos bajo `TEST_HOME`.

Después de cada acción no destructiva, verifica:

```bash
find "$TEST_HOME" -mindepth 1 -print
```

## 3. Desktop launchers

Instala la categoría:

```bash
HOME="$TEST_HOME" bash Scripts/install_ravn.sh launchers
```

Verifica que el resultado indique instalación correcta y que se creen los
launchers declarados. Ejecuta la auditoría:

```bash
HOME="$TEST_HOME" bash Scripts/install_ravn.sh --test
```

Añade manualmente un archivo no declarado en el directorio de aplicaciones y
comprueba que la limpieza no lo elimine:

```bash
mkdir -p "$TEST_HOME/.local/share/applications"
printf 'keep\n' > "$TEST_HOME/.local/share/applications/manual-test.desktop"
HOME="$TEST_HOME" bash Scripts/install_ravn.sh --clean
test -f "$TEST_HOME/.local/share/applications/manual-test.desktop"
```

Confirma además que la limpieza elimina únicamente los `.desktop` generados
y conserva los iconos fuente de RaVN.

## 4. Binaries

Ejecuta desde el menú la categoría `Binaries`, seleccionando cada acción.
Después, prueba directamente los comandos equivalentes si están disponibles:

```bash
HOME="$TEST_HOME" bash Scripts/binaries/install_binaries.sh
HOME="$TEST_HOME" bash Scripts/binaries/manage_binaries.sh --test
HOME="$TEST_HOME" bash Scripts/binaries/manage_binaries.sh --clean
```

Verifica que:

- solo se instalan los binarios declarados en
  `Scripts/binaries/restore_binaries.psv`;
- la auditoría distingue presentes y ausentes;
- `--clean` elimina los binarios declarados;
- un ejecutable creado manualmente fuera del manifiesto permanece intacto.

## 5. Configurations, precedencia y backup

Las fuentes RaVN deben estar separadas de las fuentes upstream:

```text
Configs/       # recursos upstream
Configs_RaVN/  # recursos propiedad de RaVN
```

Confirma que el manifiesto de la categoría y sus scripts usan
`Configs_RaVN`, y que `Scripts/restore_cfg.psv` no contiene una sección
`RaVN` mezclada.

Prepara una configuración upstream simulada antes de instalar:

```bash
mkdir -p "$TEST_HOME/.config/waybar"
printf 'upstream\n' > "$TEST_HOME/.config/waybar/config.jsonc"
```

Instala la categoría desde el menú o con el script correspondiente:

```bash
HOME="$TEST_HOME" bash Scripts/configurations/install_configurations.sh
```

Verifica:

1. El archivo final contiene el contenido RaVN, no `upstream`.
2. Se crea un backup bajo `~/.config/ravn-backups/configurations/`.
3. El backup conserva exactamente el contenido upstream anterior.
4. Los recursos declarados en el manifiesto se copian en sus rutas esperadas.
5. Un archivo no declarado dentro de una carpeta compartida no se elimina.

Ejemplo de comprobación:

```bash
grep -q upstream "$TEST_HOME/.config/ravn-backups/configurations"/*/config.jsonc
! grep -q upstream "$TEST_HOME/.config/waybar/config.jsonc"
```

## 6. Applications y rollback conservador

No uses el gestor real de paquetes para desinstalar software durante esta
prueba. Revisa primero el manifiesto:

```bash
cat Scripts/configurationspkg_core_RaVN.lst
HOME="$TEST_HOME" bash Scripts/applications/manage_applications.sh --test
HOME="$TEST_HOME" bash Scripts/applications/manage_applications.sh --dry-run
```

Comprueba que el dry-run:

- identifica paquetes ya instalados y los omite;
- muestra los paquetes candidatos disponibles;
- no modifica el sistema.

Si el entorno de prueba tiene una simulación de `pacman`, ejecuta también la
instalación y rollback contra esa simulación. Verifica que solo se registran y
eliminan los paquetes instalados por esa ejecución, nunca los preexistentes ni
dependencias transitivas.

## 7. Install everything

Con un `HOME` temporal, selecciona `Install everything` desde el menú y
comprueba que:

1. Se procesan las categorías en orden: applications, binaries, configurations,
   launchers.
2. Una categoría no disponible no impide procesar las siguientes.
3. El resumen final muestra el estado individual de cada categoría.
4. El comando devuelve éxito cuando no hay fallos de categorías implementadas.

También puedes ejecutar:

```bash
HOME="$TEST_HOME" bash Scripts/install_ravn.sh --all
```

## 8. Criterios para aprobar #66

Aprueba la implementación si todas las comprobaciones anteriores pasan y,
además:

- cada categoría opera solo sobre su manifiesto;
- RaVN tiene precedencia sobre recursos upstream equivalentes;
- los backups quedan separados del espacio upstream;
- las limpiezas preservan archivos no declarados y recursos reutilizables;
- el rollback de aplicaciones no elimina software preexistente;
- `master` permanece limpio después de la prueba.

Comprueba el estado final:

```bash
cd /home/ragnarok/Work/Valhalla/master
git status --short --branch
```

## 9. Resultado de la ejecución

Registra para cada sección: fecha, hash de `master`, comando utilizado,
resultado observado, archivos creados/eliminados y cualquier incidencia.
Marca una prueba como **no ejecutada**, no como aprobada, si requiere una
dependencia ausente, una sesión gráfica o un gestor de paquetes simulado.

La guía no considera implementado un rollback global de todas las categorías:
si ese requisito sigue siendo obligatorio para #66, debe registrarse como gap
pendiente aunque las pruebas individuales pasen.
