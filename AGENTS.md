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
