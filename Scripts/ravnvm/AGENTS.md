# Purpose

RavnVM is a standalone QEMU/KVM development tool for testing RaVN branches and
commits in an isolated VM. It clones or updates RaVN from GitHub inside the VM;
the host working tree is not used as the VM's source code.

# Ownership

This directory owns the RavnVM CLI, VM lifecycle, snapshots, and executable
tests. It is not part of the main dotfiles installer pipeline.

# Local Contracts

- **Entry point**: `ravnvm.sh` is the single executable interface.
- **Direct CLI**: preserve `--persist`, `--list`, `--clean`, `--install-deps`,
  `--check-deps`, `--ssh`, and `--help`, plus direct branch/commit arguments.
- **VM defaults**: use `VM_MEMORY=4G` and `VM_CPUS=2` unless overridden for the
  current invocation or session.
- **Repository source**: VM setup must clone or update the configured RaVN
  GitHub repository and check out the requested branch or commit. Do not add a
  local-working-tree execution path.
- **Cache**: use `$XDG_CACHE_HOME/ravnvm/`, preserving `archbase.qcow2` when
  cleaning snapshots and temporary VM data.

# Work Guidance

- Keep user-facing usage documentation in `README.md`; do not let help text and
  executable behavior drift from the CLI contract.
- Reuse existing VM, cache, snapshot, SSH, and usage functions before adding
  new seams.
- Make changes on a feature branch and merge them into `master` through a PR.
- Keep commits focused and preserve unrelated user changes.

# Verification

Run the executable CLI suite:

```bash
Scripts/ravnvm/tests/cli.sh
```

Also run `bash -n`, `shellcheck`, `shfmt`, and the repository pre-commit hook.
Tests should exercise external behavior through the script with isolated cache
fixtures and mocked external commands where a real VM or SSH connection would
otherwise be required.

# Child DOX Index

This directory has no child boundaries.
