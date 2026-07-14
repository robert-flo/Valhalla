# ═══════════════════════════════════════════════════════════════
# 📎 COMPATIBILITY ALIASES - Legacy command redirects
# ═══════════════════════════════════════════════════════════════
# 📚 Documentation: docs/make/aliases.md
# 🎯 Purpose: Redirect deprecated command names to new naming convention
# ──── Overview: All old commands kept for compatibility, deprecated ────

.PHONY: help-aliases vm \
        git-a git-c git-ac git-p git-st git-s git-d git-l git-lg \
        git-af git-fuck git-bye git-df git-fc git-fm git-cm \
        a c ac p l st s d lg af fuck bye df fc fm cm

# Pending aliases remain documented below and will be enabled as their make
# modules are integrated. At present, only git.mk and dev.mk are available.

# === Alias Help ===
# ═══════════════════════════════════════════════════════════════
# 📎 HELP-ALIASES - Show legacy aliases and their modern equivalents
# ═══════════════════════════════════════════════════════════════
# ──── Displays old vs new command mapping table ──────────────
help-aliases: ## Show list of legacy aliases and their modern equivalents
	@printf "\n"
	@printf "$(CYAN)═════════════════════════════════════════════════════════════════════════════════\n$(NC)"
	@printf "$(CYAN)  📎 Legacy Aliases → Modern Equivalents  $(YELLOW)(kept for compatibility)$(CYAN)           \n$(NC)"
	@printf "$(CYAN)═════════════════════════════════════════════════════════════════════════════════\n$(NC)"
	@printf "\n"
	@printf "$(BLUE)%-20s %-25s %s$(NC)\n" "LEGACY ALIAS" "MODERN COMMAND" "CATEGORY"
	@printf "$(CYAN)%-20s %-25s %s$(NC)\n" "------------" "--------------" "--------"
# Pending help entries — enable each row with its corresponding make module.
#	@printf "%-20s %-25s %s\n" "switch" "sys-apply" "System"
#	@printf "%-20s %-25s %s\n" "switch-safe" "sys-apply-safe" "System"
#	@printf "%-20s %-25s %s\n" "switch-fast" "sys-apply-fast" "System"
#	@printf "%-20s %-25s %s\n" "test" "sys-test" "System"
#	@printf "%-20s %-25s %s\n" "build" "sys-build" "System"
#	@printf "%-20s %-25s %s\n" "dry-run" "sys-dry-run" "System"
#	@printf "%-20s %-25s %s\n" "boot" "sys-boot" "System"
#	@printf "%-20s %-25s %s\n" "validate" "sys-check" "System"
#	@printf "%-20s %-25s %s\n" "debug" "sys-debug" "System"
#	@printf "%-20s %-25s %s\n" "emergency" "sys-force" "System"
#	@printf "%-20s %-25s %s\n" "fix-permissions" "sys-doctor" "System"
#	@printf "%-20s %-25s %s\n" "hardware-scan" "sys-hw-scan" "System"
#	@printf "%-20s %-25s %s\n" "sync/deploy" "sys-deploy" "Deployment"
#	@printf "%-20s %-25s %s\n" "clean" "sys-purge" "Cleanup"
#	@printf "%-20s %-25s %s\n" "deep-clean" "sys-purge" "Cleanup"
#	@printf "%-20s %-25s %s\n" "scvm / clean-vm" "sys-clean-vm" "Cleanup"
#	@printf "%-20s %-25s %s\n" "sdr / disk-repo" "sys-disk-repo" "Cleanup"
#	@printf "%-20s %-25s %s\n" "sdh / disk-home" "sys-disk-home" "Cleanup"
#	@printf "%-20s %-25s %s\n" "update" "upd-all" "Updates"
#	@printf "%-20s %-25s %s\n" "update-all" "upd-all" "Updates"
#	@printf "%-20s %-25s %s\n" "update-core" "upd-core" "Updates"
#	@printf "%-20s %-25s %s\n" "update-aur" "upd-aur" "Updates"
#	@printf "%-20s %-25s %s\n" "update-flatpak" "upd-flatpak" "Updates"
#	@printf "%-20s %-25s %s\n" "update-flatpack" "upd-flatpak" "Updates"
#	@printf "%-20s %-25s %s\n" "update-snaps" "upd-snaps" "Updates"
#	@printf "%-20s %-25s %s\n" "update-npm" "upd-npm" "Updates"
#	@printf "%-20s %-25s %s\n" "update-mise" "upd-mise" "Updates"
#	@printf "%-20s %-25s %s\n" "generations" "gen-list" "Generations"
#	@printf "%-20s %-25s %s\n" "rollback" "gen-rollback" "Generations"
#	@printf "%-20s %-25s %s\n" "diff-gens" "gen-diff" "Generations"
#	@printf "%-20s %-25s %s\n" "diff-current" "gen-diff-current" "Generations"
#	@printf "%-20s %-25s %s\n" "gen-size" "gen-sizes" "Generations"
#	@printf "%-20s %-25s %s\n" "health/status" "sys-status" "Logs"
#	@printf "%-20s %-25s %s\n" "test-network" "log-net" "Logs"
#	@printf "%-20s %-25s %s\n" "watch-logs" "log-watch" "Logs"
#	@printf "%-20s %-25s %s\n" "logs-service" "log-svc" "Logs"
#	@printf "%-20s %-25s %s\n" "boot-logs" "log-boot" "Logs"
#	@printf "%-20s %-25s %s\n" "error-logs" "log-err" "Logs"
#	@printf "%-20s %-25s %s\n" "hosts" "dev-hosts" "Dev"
#	@printf "%-20s %-25s %s\n" "search" "dev-search" "Dev"
#	@printf "%-20s %-25s %s\n" "search-inst" "dev-search-inst" "Dev"
#	@printf "%-20s %-25s %s\n" "repl" "dev-repl" "Dev"
#	@printf "%-20s %-25s %s\n" "shell" "dev-shell" "Dev"
	@printf "%-20s %-25s %s\n" "vm" "dev-vm" "Dev"
	@printf "%-20s %-25s %s\n" "dev-vm-size" "dev-vm-storage" "Dev"
#	@printf "%-20s %-25s %s\n" "closure-size" "dev-size" "Dev"
#	@printf "%-20s %-25s %s\n" "f / fmt-f" "fmt" "Format"
#	@printf "%-20s %-25s %s\n" "format / fmt-c" "fmt-check" "Format"
#	@printf "%-20s %-25s %s\n" "lint / fmt-l" "fmt-lint" "Format"
#	@printf "%-20s %-25s %s\n" "fr / fmt-r" "fmt-report" "Format"
#	@printf "%-20s %-25s %s\n" "tree" "fmt-tree" "Format"
#	@printf "%-20s %-25s %s\n" "diff-config" "fmt-diff" "Format"
#	@printf "%-20s %-25s %s\n" "docs-*" "doc-*" "Docs"
	@printf "%-20s %-25s %s\n" "a / git-a" "git-add" "Git"
	@printf "%-20s %-25s %s\n" "c / git-c" "git-commit" "Git"
	@printf "%-20s %-25s %s\n" "cm / git-cm" "git-cm \"msg\"" "Git"
	@printf "%-20s %-25s %s\n" "ac / git-ac" "git-add-commit" "Git"
	@printf "%-20s %-25s %s\n" "p / git-p" "git-push" "Git"
	@printf "%-20s %-25s %s\n" "l / git-l" "git-pull" "Git"
	@printf "%-20s %-25s %s\n" "st/s / git-st/s" "git-status" "Git"
	@printf "%-20s %-25s %s\n" "d / git-d" "git-diff" "Git"
	@printf "%-20s %-25s %s\n" "lg / git-lg" "git-log" "Git"
	@printf "%-20s %-25s %s\n" "af / git-af" "git-add-fuzzy" "Git"
	@printf "%-20s %-25s %s\n" "fuck / git-fuck" "git-amend" "Git"
	@printf "%-20s %-25s %s\n" "bye / git-bye" "git-prune-branches" "Git"
	@printf "%-20s %-25s %s\n" "df / git-df" "git-diff-fuzzy" "Git"
	@printf "%-20s %-25s %s\n" "fc / git-fc" "git-search CODE=\"..\"" "Git"
	@printf "%-20s %-25s %s\n" "fm / git-fm" "git-search MSG=\"..\"" "Git"
	@printf "\n"
	@printf "$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "• View all commands: $(BLUE)make help$(NC)\n"
	@printf "\n"

# === System (sys-) ===
# switch: sys-apply
# switch-safe: sys-apply-safe
# switch-fast: sys-apply-fast
# test: sys-test
# build: sys-build
# dry-run: sys-dry-run
# boot: sys-boot
# validate: sys-check
# debug: sys-debug
# emergency: sys-force
# fix-permissions: sys-doctor
# hardware-scan: sys-hw-scan

# === Deploy and Sync ===
# sync: sys-deploy
# deploy: sys-deploy

# === Cleanup (sys-) ===
# clean: sys-purge
# deep-clean: sys-purge
# clean-vm: sys-clean-vm
# disk-repo: sys-disk-repo
# disk-home: sys-disk-home

# === Short Cleanup Aliases ===
# scvm: sys-clean-vm
# sdr: sys-disk-repo
# sdh: sys-disk-home

# === Updates (upd-) ===
# update: upd-all
# update-all: upd-all
# update-core: upd-core
# update-aur: upd-aur
# update-flatpak: upd-flatpak
# update-flatpack: upd-flatpak
# update-snaps: upd-snaps
# update-npm: upd-npm
# update-mise: upd-mise

# === Generations (gen-) ===
# generations: gen-list
# rollback: gen-rollback
# diff-gens: gen-diff
# diff-current: gen-diff-current
# gen-size: gen-sizes

# === Logs and Diagnostics (log-) ===
# health: sys-status
# status: sys-status
# test-network: log-net
# watch-logs: log-watch
# logs-service: log-svc
# boot-logs: log-boot
# error-logs: log-err

# === Development (dev-) ===
# hosts: dev-hosts
# search: dev-search
# search-inst: dev-search-inst
# repl: dev-repl
# shell: dev-shell
vm: dev-vm
# closure-size: dev-size

# === Formatting and Structure (fmt-) ===
# fmt-f: fmt
# fmt-c: fmt-check
# fmt-l: fmt-lint
# fmt-r: fmt-report
# format: fmt-check
# lint: fmt-lint
# tree: fmt-tree
# diff-config: fmt-diff

# === Short Formatting Aliases ===
# f: fmt
# fl: fmt-lint
# fr: fmt-report

# === Documentation (doc-) ===
# docs-local: doc-local
# docs-dev: doc-dev
# docs-build: doc-build
# docs-install: doc-install
# docs-clean: doc-clean

# === Git Operations (git-) ===
git-a: git-add
git-c: git-commit
git-ac: git-add-commit
git-p: git-push
git-st: git-status
git-s: git-status
git-d: git-diff
git-l: git-pull
git-lg: git-log
git-af: git-add-fuzzy
git-fuck: git-amend
git-bye: git-prune-branches
git-df: git-diff-fuzzy
git-fc: git-search
git-fm: git-search

# === Short Git Aliases ===
a: git-add
c: git-commit
cm: git-cm
ac: git-add-commit
p: git-push
l: git-pull
st: git-status
s: git-status
d: git-diff
lg: git-log
af: git-add-fuzzy
fuck: git-amend
bye: git-prune-branches
df: git-diff-fuzzy
fc: git-search
fm: git-search
