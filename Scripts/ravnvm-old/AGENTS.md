# Purpose

RavnVM is a standalone QEMU/KVM development tool for testing RaVN branches and
commits in an isolated VM. It clones or updates RaVN from GitHub inside the VM;
the host working tree is not used as the VM's source code.

# Ownership

This directory owns the RavnVM CLI, interactive menu, VM lifecycle, snapshots,
storage reporting, and interaction tests. It is not part of the main dotfiles
installer pipeline.

# Local Contracts

- **Entry point**: `ravnvm.sh` is the single executable interface.
- **Interactive menu**: no-argument execution validates the environment, then
  exposes revision execution, storage, snapshots, resources, usage, and SSH.
- **Direct CLI**: preserve `--persist`, `--list`, `--clean`, `--install-deps`,
  `--check-deps`, `--ssh`, and `--help`, plus direct branch/commit arguments.
- **VM defaults**: use `VM_MEMORY=4G` and `VM_CPUS=2` unless overridden for the
  current invocation or session.
- **Repository source**: VM setup must clone or update the configured RaVN
  GitHub repository and check out the requested branch or commit. Do not add a
  local-working-tree execution path.
- **Cache**: use `$XDG_CACHE_HOME/ravnvm/`, preserving `archbase.qcow2` when
  cleaning snapshots and temporary VM data.
- **Make interface**: `make/dev.mk` is an alternative interaction surface over
  the same RavnVM engine. Do not duplicate VM execution logic there.
- **Visual language**: preserve the shared numbered-menu convention: green
  selection key, Nerd Font icon, then action label; use the established section,
  prompt, status, and graceful-exit helpers.

# Interactive Menu Contract

The menu currently provides:

1. Run master branch, with ephemeral or persistent mode.
2. Run dev branch, with ephemeral or persistent mode.
3. Run current branch, with ephemeral or persistent mode.
4. Run another branch or commit, with ephemeral or persistent mode.
5. Show VM storage usage.
6. Clean VM cache.
7. List VM snapshots.
8. Configure RAM and CPU for the current session.
9. Show the shared RavnVM usage information.
10. Connect to the running VM through SSH.

Missing dependencies must be handled before the normal menu and may offer only
dependency installation or exit. Empty snapshots, failed cleanup, missing VMs,
invalid input, normal exit, and Ctrl-C must return clear feedback without
corrupting cached base data.

# Work Guidance

- Keep user-facing usage documentation in `README.md`; do not let help text and
  menu behavior drift from the executable contract.
- Reuse existing VM, cache, snapshot, SSH, and usage functions before adding
  new seams.
- Keep session resource changes in memory; do not create a persistent resource
  configuration file unless explicitly requested.
- Make changes on a feature branch and merge them into `dev` through a PR.
- Keep commits focused and preserve unrelated user changes.

# Verification

Run the executable interaction suite:

```bash
Scripts/ravnvm/tests/menu.sh
Scripts/ravnvm/tests/interrupt.sh
Scripts/ravnvm/tests/snapshot.sh
```

Also run `bash -n`, `shellcheck`, `shfmt`, and the repository pre-commit hook.
Tests should exercise external behavior through the script with isolated cache
fixtures and mocked external commands where a real VM or SSH connection would
otherwise be required.

# Child DOX Index

This directory has no child boundaries.
