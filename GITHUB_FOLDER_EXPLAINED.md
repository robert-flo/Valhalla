# Guía de la carpeta `.github`

## Política aplicada en este repositorio

Este hardfork utiliza `master` como única rama permanente de integración. No
utiliza ramas `dev` ni `rc`.

El flujo esperado es:

```text
issue → rama y worktree temporales → pull request → master
```

Los commits directos a `master` están prohibidos. Esta restricción se aplica con
la protección de rama de GitHub. Los workflows de GitHub Actions validan los
cambios, pero por sí solos no pueden impedir un push directo.

## Estructura relevante

```text
.github/
├── FUNDING.yml
├── ISSUE_TEMPLATE/
│   ├── bug_report.yml
│   ├── custom.yml
│   ├── documentation_update.yml
│   └── feature_request.yml
├── PULL_REQUEST_TEMPLATE.md
└── workflows/
    ├── ci.yml
    └── lock.yml
```

## Plantillas de issues

Los archivos de `ISSUE_TEMPLATE` proporcionan formularios para bugs,
solicitudes de funcionalidades, documentación y casos generales. GitHub los
muestra automáticamente al crear un issue.

## Plantilla de pull request

`PULL_REQUEST_TEMPLATE.md` proporciona el formato inicial del cuerpo de un PR.
Los PR deben apuntar directamente a `master`, relacionar el issue correspondiente
y documentar las validaciones ejecutadas.

La plantilla facilita la revisión, pero no aplica la protección de la rama.

## Workflow de validación

`workflows/ci.yml` se ejecuta en tres situaciones:

1. `pull_request` hacia `master`.
2. `push` a `master`, normalmente producido por el merge de un PR.
3. Ejecución manual mediante `workflow_dispatch`.

El workflow ejecuta un único job, `Validate repository changes`, que:

- comprueba errores de whitespace en el rango modificado;
- valida con `bash -n` los scripts shell modificados;
- verifica que el manifiesto de restauración conserve un solo delimitador RaVN
  y entradas PSV de cuatro columnas.

### Por qué CI aparece en el PR y después del merge

La ejecución del PR valida el cambio antes de que llegue a `master`. Esta es la
ejecución que debe ser requerida por la protección de rama.

Cuando se fusiona el PR, GitHub genera un `push` sobre `master`; por eso CI se
ejecuta de nuevo. Esa segunda ejecución comprueba el commit resultante, pero no
puede deshacer ni prevenir un cambio que ya fue fusionado.

## Workflow de mantenimiento

`workflows/lock.yml` se ejecuta diariamente y marca como inactivos los issues y
PR abandonados. No interviene en el modelo de ramas ni realiza commits.

## Componentes eliminados

No aplican a este hardfork y fueron retirados:

- promoción automática `dev → rc`;
- promoción automática `rc → master`;
- scripts de generación de PR de promoción;
- calendario y refresh trimestral de releases;
- release automático específico de HyDE;
- advertencia que rechazaba PR dirigidos a `master`;
- workflows que hacían push directo a `master`.

## Protección necesaria en GitHub

La rama `master` debe tener estas reglas:

- require a pull request before merging;
- aplicar la regla también a administradores;
- no permitir force pushes;
- requerir `Validate repository changes` antes del merge, una vez que el workflow
  esté disponible en GitHub.

Con estas reglas, el flujo conserva lo ya implementado: issue, rama/worktree con
el mismo nombre, commits atómicos, PR contra `master`, CI, merge y limpieza.
