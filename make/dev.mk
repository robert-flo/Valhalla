# ═══════════════════════════════════════════════════════════════
# 🖥️  RAVNVM DEVELOPMENT - Isolated VM testing
# ═══════════════════════════════════════════════════════════════
# 📚 Documentation: Scripts/ravnvm/README.md
# 🎯 Purpose: Run, inspect and manage isolated RaVN development VMs
# ──── Overview: 9 targets for the complete RavnVM workflow ───
#
# 📎 Aliases & Targets:
#    ALIAS  TARGET                         DESCRIPTION
#    vm     dev-vm                        Run an ephemeral VM for REF
#    —      dev-vm-persist                Run a persistent VM for REF
#    —      dev-vm-list                   List cached revision snapshots
#    —      dev-vm-clean                  Clean snapshots and temporary data
#    —      dev-vm-setup                  Check or install host dependencies
#    —      dev-vm-storage                Show cache and filesystem usage
#    —      dev-vm-size                   Alias for dev-vm-storage
#    —      dev-vm-ssh                    Connect to the running VM via SSH
#    —      dev-vm-install-ssh-alias      Install the ssh ravnvm host alias
#
# 🧪 Dry Run (preview without executing RavnVM):
#    make dev-vm                    DRY_RUN=1   · preview an ephemeral VM
#    make dev-vm-persist            DRY_RUN=1   · preview a persistent VM
#    make dev-vm-clean              DRY_RUN=1   · skip cache cleanup
#    make dev-vm-setup              DRY_RUN=1   · skip dependency changes
#    make dev-vm-ssh                DRY_RUN=1   · skip the SSH connection
#    make dev-vm-install-ssh-alias  DRY_RUN=1   · skip SSH alias installation
#    (help is read-only; list and storage targets are also previewed in dry-run)

RAVNVM ?= $(SCRIPTS_DIR)/ravnvm/ravnvm.sh
GIT ?= git
REF ?= $(shell ref=$$($(GIT) branch --show-current 2>/dev/null); \
	if [ -n "$$ref" ]; then printf '%s' "$$ref"; \
	else $(GIT) rev-parse HEAD 2>/dev/null || printf 'master'; fi)
VM_MEMORY ?= 4G
VM_CPUS ?= 2
VM_EXTRA_ARGS ?=
VM_QEMU_OVERRIDE ?=
DRY_RUN ?= 0

RAVNVM_TARGETS := dev-vm dev-vm-persist dev-vm-list dev-vm-clean dev-vm-setup \
	dev-vm-storage dev-vm-size dev-vm-ssh dev-vm-install-ssh-alias

.PHONY: help $(RAVNVM_TARGETS)

define run-ravnvm
	@if [ "$(DRY_RUN)" = "1" ]; then \
		printf "  ▶ [dry-run] VM_MEMORY='%s' VM_CPUS='%s' VM_EXTRA_ARGS='%s' VM_QEMU_OVERRIDE='%s' %s%s\n" \
			'$(VM_MEMORY)' '$(VM_CPUS)' '$(value VM_EXTRA_ARGS)' '$(value VM_QEMU_OVERRIDE)' '$(RAVNVM)' ' $(1)'; \
	else \
		VM_MEMORY='$(VM_MEMORY)' VM_CPUS='$(VM_CPUS)' \
			VM_EXTRA_ARGS='$(value VM_EXTRA_ARGS)' VM_QEMU_OVERRIDE='$(value VM_QEMU_OVERRIDE)' \
			'$(RAVNVM)' $(1); \
	fi
endef

help: ## Show the RavnVM development targets
	@printf '$(CYAN)RavnVM development targets$(NC)\n'
	@printf '  make dev-vm             Run an ephemeral VM (REF, VM_MEMORY, VM_CPUS)\n'
	@printf '  make dev-vm-persist     Run a persistent VM\n'
	@printf '  make dev-vm-list        List cached snapshots\n'
	@printf '  make dev-vm-clean       Clean snapshots and temporary cache data\n'
	@printf '  make dev-vm-setup       Check or install VM dependencies\n'
	@printf '  make dev-vm-storage     Show RavnVM storage usage\n'
	@printf '  make dev-vm-size        Alias for dev-vm-storage\n'
	@printf '  make dev-vm-ssh         Connect to the running VM via SSH\n'
	@printf '  make dev-vm-install-ssh-alias  Install the ssh ravnvm host alias\n'
	@printf '\nSet DRY_RUN=1 to print commands without executing RavnVM.\n'

dev-vm: ## Run an ephemeral VM
	$(call run-ravnvm,$(REF))

dev-vm-persist: ## Run a persistent VM
	$(call run-ravnvm,--persist $(REF))

dev-vm-list: ## List cached snapshots
	$(call run-ravnvm,--list)

dev-vm-clean: ## Clean snapshots and temporary cache data
	$(call run-ravnvm,--clean)

dev-vm-storage: ## Show RavnVM storage usage
	$(call run-ravnvm,--storage)

dev-vm-size: dev-vm-storage ## Compatibility alias for storage usage

dev-vm-ssh: ## Connect to the running VM via SSH
	$(call run-ravnvm,--ssh)

dev-vm-install-ssh-alias: ## Install the ssh ravnvm host alias
	$(call run-ravnvm,--install-ssh-alias)

dev-vm-setup: ## Check or install VM dependencies
	@if [ "$(DRY_RUN)" = "1" ]; then \
		printf '  ▶ [dry-run] %s --check-deps\n' '$(RAVNVM)'; \
		printf '  ▶ [dry-run] %s --install-deps\n' '$(RAVNVM)'; \
	elif ! '$(RAVNVM)' --check-deps; then \
		'$(RAVNVM)' --install-deps; \
	fi
