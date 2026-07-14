RAVNVM ?= $(SCRIPTS_DIR)/ravnvm/ravnvm.sh
REF ?= $(shell git branch --show-current 2>/dev/null || printf 'master')
VM_MEMORY ?= 4G
VM_CPUS ?= 2
VM_EXTRA_ARGS ?=
VM_QEMU_OVERRIDE ?=
DRY_RUN ?= 0

.PHONY: help dev-vm dev-vm-persist dev-vm-list dev-vm-clean dev-vm-setup dev-vm-size dev-vm-ssh

define run-ravnvm
	@if [ "$(DRY_RUN)" = "1" ]; then \
		printf '  ▶ [dry-run] %s%s\n' '$(RAVNVM)' ' $(1)'; \
	else \
		VM_MEMORY='$(VM_MEMORY)' VM_CPUS='$(VM_CPUS)' \
			VM_EXTRA_ARGS='$(VM_EXTRA_ARGS)' VM_QEMU_OVERRIDE='$(VM_QEMU_OVERRIDE)' \
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
	@printf '  make dev-vm-size        Show RavnVM storage usage\n'
	@printf '  make dev-vm-ssh         Connect to the running VM via SSH\n'
	@printf '\nSet DRY_RUN=1 to print commands without executing RavnVM.\n'

dev-vm: ## Run an ephemeral VM
	$(call run-ravnvm,$(REF))

dev-vm-persist: ## Run a persistent VM
	$(call run-ravnvm,--persist $(REF))

dev-vm-list: ## List cached snapshots
	$(call run-ravnvm,--list)

dev-vm-clean: ## Clean snapshots and temporary cache data
	$(call run-ravnvm,--clean)

dev-vm-size: ## Show RavnVM storage usage
	$(call run-ravnvm,--storage)

dev-vm-ssh: ## Connect to the running VM via SSH
	$(call run-ravnvm,--ssh)

dev-vm-setup: ## Check or install VM dependencies
	@if [ "$(DRY_RUN)" = "1" ]; then \
		printf '  ▶ [dry-run] %s --check-deps\n' '$(RAVNVM)'; \
		printf '  ▶ [dry-run] %s --install-deps\n' '$(RAVNVM)'; \
	elif ! '$(RAVNVM)' --check-deps; then \
		'$(RAVNVM)' --install-deps; \
	fi
