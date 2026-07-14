## Agent skills

### Issue tracker

GitHub Issues usando `gh` CLI. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context — un `CONTEXT.md` + `docs/adr/` en la raíz. See `docs/agents/domain.md`.

### Historial de pull requests

- Mantener lineal la rama de cada pull request y crear un único merge commit hacia `master`.
- Antes de fusionar, rebasar la rama sobre `origin/master`; no fusionar `master` dentro de la rama.
- Después de un rebase, actualizar la rama remota únicamente con `git push --force-with-lease`.
- Si una rama automatizada no puede rebasarse de forma segura, recrearla desde `origin/master` antes de fusionarla.

### Changelog de pull requests

- Seleccionar una única etiqueta `changelog:<categoría>` o `changelog:skip`.
- Generar la entrada localmente con `.github/scripts/update-pr-changelog.sh`,
  proporcionando `PR_NUMBER`, `PR_URL`, `PR_TITLE` y `PR_LABELS`.
- Revisar el resultado, ejecutar el generador una segunda vez para comprobar
  idempotencia y ejecutar `tests/changelog-automation.sh`.
- Confirmar `CHANGELOG.md` con `chore(changelog): update PR #<número>` antes de
  solicitar revisión. CI únicamente valida el resultado y nunca escribe en la rama.

### Código incorporado por RaVN

Esta convención se aplica exclusivamente cuando RaVN señala de forma explícita
código nuevo o archivos no rastreados que acaba de agregar al repositorio. En
ese caso, se debe asumir que la implementación ya es funcional, ha sido probada
en el uso diario y está lista para integrarse. El trabajo debe partir de ella y
preservar su diseño, arquitectura, lenguaje visual y comportamiento reconocible.

- `to-tickets <ruta>` solicita integrar el código señalado. Se permiten mejoras
  incrementales, pero se debe conservar la esencia de la implementación y no
  convertir la integración en una refactorización.
- `grill-with docs <ruta>` solicita evaluar una refactorización del código
  señalado mediante una sesión `grill-me`. No implementarla hasta alcanzar con
  RaVN un acuerdo explícito sobre su alcance, decisiones y puntos de validación.
- Aplicar las mejoras de forma incremental y atómica, preservando primero el
  estado funcional aportado.
- No convertir una integración en una reescritura sin autorización explícita.
- Fuera de este alcance, `to-tickets` continúa siendo el funcionamiento normal
  esperado del repositorio.

### Cambios personales RaVN

`Scripts/restore_cfg.psv` contiene configuraciones upstream y configuraciones
personales de RaVN dentro del mismo archivo.

La sección personal comienza exclusivamente después de este delimitador:

```text
# --------------------------------------------------- // RaVN
```

#### Reglas de edición

- Debe existir un único delimitador `RaVN`.
- Todo lo situado arriba del delimitador pertenece al proyecto upstream.
- Todo lo situado debajo del delimitador pertenece a la configuración personal de RaVN.
- Las nuevas entradas personales deben agregarse debajo del delimitador.
- Las entradas provenientes de upstream deben agregarse o actualizarse arriba del delimitador.
- No mover, reorganizar, modificar ni eliminar entradas upstream al trabajar en cambios personales.
- No mover entradas personales hacia la sección upstream.
- Al sincronizar cambios de upstream, preservar intacta la sección RaVN salvo que la tarea solicite expresamente modificarla.
- Si una entrada nueva de upstream coincide con una entrada RaVN, no resolver automáticamente la duplicación: informar el conflicto y solicitar instrucciones.
- Dentro de la sección RaVN se pueden utilizar comentarios para crear subsecciones lógicas.
- Mantener el formato PSV de cuatro columnas: `flag|path|target|dependency`.
- Antes de finalizar, comprobar que el delimitador continúa presente y que no se mezclaron entradas de ambas secciones.

#### Alcance

Esta convención se aplica a:

- `Scripts/restore_cfg.psv`
