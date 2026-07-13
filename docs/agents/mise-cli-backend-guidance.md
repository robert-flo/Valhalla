# Guidance: Using mise for CLI Tasks

These conclusions came from the completed OpenCode `mise` pilot and should guide future RaVN task design. `mise` is the approved default for versioned npm CLIs; `omarchy-npx-install` remains an explicit fallback for legacy or justified exceptions.

## Recommended role

Use `mise` as the preferred backend for CLI tools whose runtimes and versions can be managed explicitly. Keep the installer strategy task-specific rather than forcing every tool through one backend.

## Shell initialization boundary

Tasks must not depend on `mise activate` or on a user's interactive shell initialization to claim success. Shell activation can differ by shell, session type, login configuration, Docker, scripts, and `sudo` environments.

The reliable task boundary is an owned wrapper that invokes the tool through an explicit mise environment:

```text
wrapper → mise exec → task-owned configuration → real executable
```

The wrapper must be tested from a clean shell and a non-interactive process.

Shell activation may be offered as an optional convenience for users who want direct access to managed tools, but it must not be a prerequisite for installation or verification.

## Version policy

The shared `mise-cli` backend follows RaVN's rolling-tool policy:

- `CLI_PACKAGE` and `CLI_COMMAND` are the only required descriptor fields.
- `CLI_DESCRIPTION` defaults to `<command> managed by mise`.
- `CLI_VERSION` defaults to `latest`; `CLI_NODE_VERSION` defaults to `latest`.
- `CLI_VERIFY_ARGS` defaults to `--version` and must produce non-empty output.
- `allow_builds = true` and `--ignore-scripts=false` are emitted in the task-owned mise configuration.
- The selected and resolved versions are recorded in runner evidence so upgrades and failures are diagnosable.

The canonical descriptor should therefore remain small:

```bash
CLI_PACKAGE="vendor/package"
CLI_COMMAND="tool"
source "${RAVN_DIR}/framework/mise-cli.sh"
mise_cli_task
```

## Runtime and package policy

- Declare runtimes such as Node as explicit task dependencies.
- Keep the package name, executable name, runtime version, configuration path, wrapper path, and owned resources visible in the task.
- Test from a clean environment; the host may already have runtimes that hide missing dependencies.

## Lifecycle scripts and post-install behavior

The OpenCode pilot initially failed because mise/npm skipped the package's `postinstall` script. A wrapper existing on `PATH` was not proof that the tool was usable.

Tasks installing npm packages must determine whether lifecycle scripts are required, allow only the behavior needed by the package, and verify the real executable afterward. `verify()` must catch packages that install a launcher but fail during first use.

## Reset ownership

`reset()` should remove only resources owned by the task: wrappers, task-owned configuration, and explicitly owned runtime installation state. Shared mise caches require care; a task must not remove a runtime or package version that another task may rely on unless ownership is explicit.

## Testing requirements

Every mise-backed CLI task should cover:

- clean installation;
- execution from a fresh shell;
- idempotent rerun;
- missing runtime behavior;
- network or package-resolution failure;
- real post-install verification;
- reset and post-reset verification;
- clean reinstall.

Docker or a VM must be preferred over host-only tests when validating runtime availability or shell environment assumptions.
