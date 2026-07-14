# ═══════════════════════════════════════════════════════════════
# 🔀 GIT OPERATIONS - Version control and backup
# ═══════════════════════════════════════════════════════════════
# 📚 Documentation: docs/src/content/docs/makefile/06-git.mdx
# 🎯 Purpose: Stage, commit, push and inspect git repository state
# ──── Overview: 7 targets for the full git commit/push cycle ─
#
# 📎 Aliases & Targets:
#    ALIAS          TARGET                   DESCRIPTION
#    a  / git-a     git-add                  Stage all changes
#    c  / git-c     git-commit               Quick timestamped commit
#    cm / git-cm    git-cm MSG="..."         Commit with custom message
#    ac / git-ac    git-add-commit           Stage & commit together
#    p  / git-p     git-push                 Push commits to remote
#    l  / git-l     git-pull                 Pull remote changes
#    st / git-st    git-status               Show repository state
#    s  / git-s     git-status               Show repository state
#    d  / git-d     git-diff                 Show uncommitted diffs
#    lg / git-lg    git-log                  Show commit log history
#    af / git-af    git-add-fuzzy            Interactively stage (fzf)
#    fuck/git-fuck  git-amend                Amend last commit (MSG="...")
#    bye / git-bye  git-prune-branches       Delete local merged branches
#    df / git-df    git-diff-fuzzy           Fuzzy select commit to diff
#    fc / git-fc    git-search CODE="..."    Search history by code modification
#    fm / git-fm    git-search MSG="..."     Search history by message query
#
# 🧪 Dry Run (preview without executing):
#    make git-add             DRY_RUN=1   · skip git add
#    make git-commit          DRY_RUN=1   · skip git commit
#    make git-push            DRY_RUN=1   · skip git push
#    make git-pull            DRY_RUN=1   · skip git pull
#    make git-amend           DRY_RUN=1   · skip git commit --amend
#    make git-prune-branches  DRY_RUN=1   · skip git branch -d
#    (git-status, git-diff, git-log, git-add-fuzzy, git-diff-fuzzy, git-search are read-only)

DRY_RUN ?= 0
export DRY_RUN
ifeq ($(DRY_RUN),1)
  EXEC = echo "  ▶ [dry-run]"
else
  EXEC =
endif

# Intercept positional arguments as the commit message for cm / git-cm targets
ifeq ($(firstword $(MAKECMDGOALS)),$(filter $(firstword $(MAKECMDGOALS)),git-cm cm))
  MSG ?= $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  # Avoid erroring out on positional arguments treated as targets
  %:
	@:
endif

RAVN_WTS_DIR ?= $(abspath $(RAVN_DIR)/..)

.PHONY: git-add git-commit git-cm git-add-commit git-push git-pull git-status git-diff git-log git-setup git-sync git-diff-dev git-diff-rc git-diff-here \
        git-add-fuzzy git-amend git-prune-branches git-diff-fuzzy git-search

# ═══════════════════════════════════════════════════════════════
# 💾 GIT-ADD - Stage all modified/new files for commit
# ═══════════════════════════════════════════════════════════════
# ──── Stage: Adds all modified/new files to the git index ────
git-add: ## Stage all changes for git
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)💾 git-add · staging all changes$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@CHANGED=$$(git status --short | wc -l); \
	if [ $$CHANGED -gt 0 ]; then \
		printf "  adding $$CHANGED file(s) to staging area...\n"; \
		$(EXEC) git add .; \
		printf "$(GREEN)  ✓ staged $$CHANGED file(s)$(NC)\n\n"; \
		git status --short | sed 's/^/  /'; \
	else \
		printf "$(GREEN)  ✓  nothing to stage — working tree is clean$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • commit staged changes: $(BLUE)make git-commit$(NC)\n"
	@printf "  • stage and commit in one step: $(BLUE)make git-add-commit$(NC)\n"
	@printf "  • inspect what changed: $(BLUE)make git-diff$(NC)\n\n"
endif

# ═══════════════════════════════════════════════════════════════
# 📝 GIT-COMMIT - Create a timestamped commit from staged changes
# ═══════════════════════════════════════════════════════════════
# ──── Commit: Stages all and creates commit with timestamp ───
git-commit: ## Quick commit with timestamp
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)📝 git-commit · timestamped snapshot$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if [ -n "$$(git status --porcelain)" ]; then \
		printf "  staging changes...\n"; \
		$(EXEC) git add .; \
		COMMIT_MSG="config: update $$(date '+%Y-%m-%d %H:%M:%S')"; \
		printf "  commit: $(GREEN)$$COMMIT_MSG$(NC)\n\n"; \
		$(EXEC) git commit --signoff -m "$$COMMIT_MSG" || exit 1; \
		COMMIT_HASH=$$(git rev-parse --short HEAD); \
		BRANCH=$$(git branch --show-current); \
		printf "$(GREEN)  ✓ $(NC)$(DIM)$$COMMIT_HASH$(NC)  $$BRANCH\n"; \
	else \
		printf "$(GREEN)  ✓  nothing to commit — working tree is clean$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • push to remote: $(BLUE)make git-push$(NC)\n"
	@printf "  • view recent history: $(BLUE)make git-log$(NC)\n"
	@printf "  • check repo state:     $(BLUE)make git-status$(NC)\n\n"
endif

# ═══════════════════════════════════════════════════════════════
# 📝 GIT-CM - Create a commit from staged changes with a custom message
# ═══════════════════════════════════════════════════════════════
# ──── Commit: Stages all and creates commit with custom message ─
git-cm: ## Commit with custom message (use MSG="message")
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)📝 git-cm · custom commit$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if [ -z "$(MSG)" ]; then \
		printf "$(RED)  ✗ please specify MSG=\"message\" to commit$(NC)\n"; \
		printf "  example: $(BLUE)make git-cm MSG=\"your commit message\"$(NC)\n\n"; \
		exit 1; \
	fi
	@if [ -n "$$(git status --porcelain)" ]; then \
		printf "  staging changes...\n"; \
		$(EXEC) git add .; \
		printf "  commit: $(GREEN)$(MSG)$(NC)\n\n"; \
		$(EXEC) git commit --signoff -m "$(MSG)" || exit 1; \
		COMMIT_HASH=$$(git rev-parse --short HEAD); \
		BRANCH=$$(git branch --show-current); \
		printf "$(GREEN)  ✓ $(NC)$(DIM)$$COMMIT_HASH$(NC)  $$BRANCH\n"; \
	else \
		printf "$(GREEN)  ✓  nothing to commit — working tree is clean$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • push to remote: $(BLUE)make git-push$(NC)\n"
	@printf "  • view recent history: $(BLUE)make git-log$(NC)\n"
	@printf "  • check repo state:     $(BLUE)make git-status$(NC)\n\n"
endif

# ═══════════════════════════════════════════════════════════════
# 🔗 GIT-ADD-COMMIT - Stage and commit all changes in one step
# ═══════════════════════════════════════════════════════════════
# ──── Composite: Calls git-add then git-commit with EMBEDDED=1 ─
git-add-commit: ## Stage and commit all changes together
	@$(MAKE) -s git-add EMBEDDED=1
	@$(MAKE) -s git-commit EMBEDDED=1
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • push to remote: $(BLUE)make git-push$(NC)\n"
	@printf "  • check repo state:     $(BLUE)make git-status$(NC)\n"
	@printf "  • view recent history: $(BLUE)make git-log$(NC)\n\n"
endif

# ═══════════════════════════════════════════════════════════════
# ☁️  GIT-PUSH - Sync local commits to remote repository
# ═══════════════════════════════════════════════════════════════
# ──── Push: Sends unpushed commits to origin via git push ────
git-push: ## Push to remote
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)☁️  git-push · sync to remote$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@BRANCH=$$(git branch --show-current); \
	REMOTE=$$(git remote get-url origin 2>/dev/null | sed -E 's|.*github.com[:/]([^/]+/[^/]+)(\.git)?$$|\1|' | sed 's|\.git$$||'); \
	printf "  $(DIM)branch:$(NC) $$BRANCH  $(DIM)remote:$(NC) $$REMOTE\n"; \
	if git rev-parse --verify --quiet refs/remotes/origin/$$BRANCH >/dev/null 2>&1; then \
		UNPUSHED=$$(git log origin/$$BRANCH..HEAD --oneline 2>/dev/null | wc -l); \
		if [ $$UNPUSHED -gt 0 ]; then \
			printf "\n  pushing $$UNPUSHED commit(s)...\n"; \
			$(EXEC) git push || exit 1; \
			printf "$(GREEN)  ✓ pushed to remote$(NC)\n"; \
		else \
			printf "$(GREEN)  ✓  everything up-to-date$(NC)\n"; \
		fi; \
	else \
		printf "\n  pushing new branch $$BRANCH to remote...\n"; \
		$(EXEC) git push --set-upstream origin "$$BRANCH" || exit 1; \
		printf "$(GREEN)  ✓ pushed to remote$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • verify remote history: $(BLUE)make git-log$(NC)\n"
	@printf "  • check repo state: $(BLUE)make git-status$(NC)\n"
	@printf "  • apply system after push: $(BLUE)make sys-apply$(NC)\n\n"
endif

# ═══════════════════════════════════════════════════════════════
# ☁️  GIT-PULL - Pull updates from remote repository
# ═══════════════════════════════════════════════════════════════
# ──── Pull: Fetches and integrates remote changes ────────────
git-pull: ## Pull updates from remote
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)☁️  git-pull · pull from remote$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@BRANCH=$$(git branch --show-current); \
	REMOTE=$$(git remote get-url origin 2>/dev/null | sed -E 's|.*github.com[:/]([^/]+/[^/]+)(\.git)?$$|\1|' | sed 's|\.git$$||'); \
	printf "  $(DIM)branch:$(NC) $$BRANCH  $(DIM)remote:$(NC) $$REMOTE\n\n"; \
	if [ "$$DRY_RUN" = "1" ]; then \
		printf "  ▶ [dry-run] git pull\n"; \
	else \
		printf "  pulling changes from remote...\n\n"; \
		git pull || exit 1; \
		printf "\n$(GREEN)  ✓ pulled from remote$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • check repo state:     $(BLUE)make git-status$(NC)\n"
	@printf "  • view history:         $(BLUE)make git-log$(NC)\n"
	@printf "  • validate formatting:  $(BLUE)make fmt-check$(NC)\n\n"
endif

# ═══════════════════════════════════════════════════════════════
# 📊 GIT-STATUS - Show repository state and recent commits
# ═══════════════════════════════════════════════════════════════
# ──── Status: Branch, remote, local changes, last 3 commits ─
git-status: ## Show current repository state
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)📊 git-status · repository overview$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if git rev-parse --git-dir > /dev/null 2>&1; then \
		REMOTE_URL=$$(git remote get-url origin 2>/dev/null); \
		REPO_NAME=$$(echo "$$REMOTE_URL" | sed -E 's|.*github.com[:/]([^/]+/[^/]+)(\.git)?$$|\1|' | sed 's|\.git$$||'); \
		BRANCH=$$(git branch --show-current); \
		AHEAD=$$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0); \
		BEHIND=$$(git rev-list --count HEAD..@{u} 2>/dev/null || echo 0); \
		STAGED=$$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' '); \
		UNSTAGED=$$(git diff --name-only 2>/dev/null | wc -l | tr -d ' '); \
		UNTRACKED=$$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' '); \
		GIT_DIR=$$(realpath "$$(git rev-parse --git-dir 2>/dev/null)"); \
		COMMON_DIR=$$(realpath "$$(git rev-parse --git-common-dir 2>/dev/null)"); \
		if [ "$$GIT_DIR" != "$$COMMON_DIR" ]; then WORKTREE="yes"; else WORKTREE="no"; fi; \
		printf "  $(DIM)repo:$(NC)      $$REPO_NAME\n"; \
		printf "  $(DIM)branch:$(NC)    $$BRANCH"; \
		if [ "$$AHEAD" -gt 0 ] && [ "$$BEHIND" -gt 0 ]; then \
			printf "  $(YELLOW)⇕ ↑$$AHEAD ↓$$BEHIND$(NC)"; \
		elif [ "$$AHEAD" -gt 0 ]; then \
			printf "  $(YELLOW)↑ $$AHEAD ahead$(NC)"; \
		elif [ "$$BEHIND" -gt 0 ]; then \
			printf "  $(RED)↓ $$BEHIND behind$(NC)"; \
		fi; \
		printf "\n"; \
		printf "  $(DIM)path:$(NC)      $(PWD)\n"; \
		printf "  $(DIM)worktree:$(NC)  $$WORKTREE\n\n"; \
		if [ "$$STAGED" -eq 0 ] && [ "$$UNSTAGED" -eq 0 ] && [ "$$UNTRACKED" -eq 0 ]; then \
			printf "  $(GREEN)✓ nothing to commit — working tree clean$(NC)\n"; \
			printf "\n"; \
		else \
			if [ "$$STAGED" -gt 0 ]; then \
				printf "  $(GREEN)staged:$(NC)    $$STAGED file(s)\n"; \
				git diff --cached --name-only 2>/dev/null | while IFS= read -r f; do printf "    $(GREEN)+$(NC) $$f\n"; done; \
				printf "\n"; \
			fi; \
			if [ "$$UNSTAGED" -gt 0 ]; then \
				printf "  $(YELLOW)modified:$(NC)  $$UNSTAGED file(s)\n"; \
				git diff --name-only 2>/dev/null | while IFS= read -r f; do printf "    $(YELLOW)~$(NC) $$f\n"; done; \
				printf "\n"; \
			fi; \
			if [ "$$UNTRACKED" -gt 0 ]; then \
				printf "  $(DIM)untracked:$(NC) $$UNTRACKED file(s)\n"; \
				git ls-files --others --exclude-standard 2>/dev/null | while IFS= read -r f; do printf "    $(DIM)?$(NC) $$f\n"; done; \
				printf "\n"; \
			fi; \
		fi; \
		printf "  $(DIM)recent commits:$(NC)\n"; \
		git --no-pager log --max-count=5 --pretty=format:"  %C(green)%h%C(reset)  %<(50,trunc)%s  %C(dim)%<(15)%ar%C(reset)" 2>/dev/null; \
		printf "\n"; \
	else \
		printf "$(YELLOW)  ⚠  not a git repository$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • stage and commit: $(BLUE)make git-add-commit$(NC)\n"
	@printf "  • push changes:     $(BLUE)make git-push$(NC)\n"
	@printf "  • full history:     $(BLUE)make git-log$(NC)\n\n"
endif

# ═══════════════════════════════════════════════════════════════
# 🔄 GIT-DIFF - Show uncommitted changes in the repository
# ═══════════════════════════════════════════════════════════════
# ──── Diff: All repository files — summary and full detail ────
git-diff: ## Show uncommitted changes in the repository
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🔄 git-diff · repository changes$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if git diff --quiet 2>/dev/null; then \
		printf "$(GREEN)  ✓ no uncommitted changes in repository$(NC)\n"; \
	else \
		if command -v hunk >/dev/null 2>&1; then \
			hunk diff; \
		else \
			git diff --color=always 2>/dev/null || git diff; \
		fi; \
		printf "\n"; \
		CHANGED_FILES=$$(git diff --name-only 2>/dev/null | wc -l); \
		ADDED_LINES=$$(git diff --numstat 2>/dev/null | awk '{sum+=$$1} END {print sum+0}'); \
		DELETED_LINES=$$(git diff --numstat 2>/dev/null | awk '{sum+=$$2} END {print sum+0}'); \
		printf "  $(DIM)files:$(NC) $$CHANGED_FILES  $(GREEN)+$$ADDED_LINES$(NC)  $(RED)-$$DELETED_LINES$(NC)\n\n"; \
		git --no-pager diff --stat --color=always 2>/dev/null || git --no-pager diff --stat; \
		printf "\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • stage and commit: $(BLUE)make git-add-commit$(NC)\n"
	@printf "  • validate scripts: $(BLUE)make fmt-lint$(NC)\n"
	@printf "  • test in RavnVM:   $(BLUE)make dev-vm$(NC)\n\n"
endif

# ═══════════════════════════════════════════════════════════════
# 📜 GIT-LOG - Show recent commit history
# ═══════════════════════════════════════════════════════════════
# ──── Log: Last 15 commits — short hash, message, age ────────
git-log: ## Show recent commit history
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)📜 git-log · recent history$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if git rev-parse --git-dir > /dev/null 2>&1; then \
		git --no-pager log --max-count=15 --pretty=format:"  %C(green)%h%C(reset)  %<(58,trunc)%s  %C(dim)%<(15)%ar%C(reset)" 2>/dev/null; \
	else \
		printf "$(YELLOW)  ⚠  not a git repository$(NC)\n"; \
	fi
	@printf "\n"

# ═══════════════════════════════════════════════════════════════
# 🚀 GIT-SETUP - Clone a repo and create all worktrees ready to push
# ═══════════════════════════════════════════════════════════════
# ──── Setup: bare clone + all worktrees + upstream tracking ──
# ──── Usage: make git-setup REPO=git@github.com:user/repo.git ─
#
# Locations (can be overridden via environment variables):
#   Bare objects:  $$BARE_HOME/<repo>       (default: ~/.local/share/git-bare/<repo>)
#   Worktrees:     $$WORKTREES_HOME/<repo>  (default: ~/Work/<repo>)
git-setup: ## Clone a repo as bare + create all worktrees with upstream (use REPO=url)
	@printf "\n"
	@printf "$(CYAN)🚀 git-setup · bare clone + worktrees$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@if [ -z "$(REPO)" ] || [ "$(REPO)" = "RaVN" ]; then \
		printf "$(RED)  ✗ missing or invalid required argument$(NC)\n\n"; \
		printf "  usage:  $(BLUE)make git-setup REPO=git@github.com:robert-flo/RaVN.git$(NC)\n\n"; \
		printf "  override locations:\n"; \
		printf "    $(DIM)BARE_HOME$(NC)       bare objects dir   (default: $(DIM)~/.local/share/git-bare$(NC))\n"; \
		printf "    $(DIM)WORKTREES_HOME$(NC)  worktrees base dir (default: $(DIM)~/Work$(NC))\n\n"; \
		exit 1; \
	fi; \
	if command -v git-bare-clone >/dev/null 2>&1; then \
		SCRIPT="git-bare-clone"; \
	elif [ -f "Configs/.local/bin/git-bare-clone" ]; then \
		SCRIPT="./Configs/.local/bin/git-bare-clone"; \
	else \
		SCRIPT=""; \
	fi; \
	if [ -z "$$SCRIPT" ]; then \
		printf "$(RED)  ✗ git-bare-clone not found$(NC)\n\n"; \
		printf "  It should be present at Configs/.local/bin/git-bare-clone\n"; \
		printf "  Ensure the file exists and is executable.\n\n"; \
		exit 1; \
	fi; \
	if [ "$$DRY_RUN" = "1" ]; then \
		printf "  ▶ [dry-run] $$SCRIPT $(REPO)\n"; \
	else \
		$$SCRIPT $(REPO); \
	fi
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@REPO_NAME=$$(basename "$(REPO)" .git); \
	WTHOME=$${WORKTREES_HOME:-$$HOME/Work}; \
	printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"; \
	printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"; \
	printf "  • enter a worktree:  $(BLUE)cd $$WTHOME/$$REPO_NAME/<branch>$(NC)\n"; \
	printf "  • check git status:  $(BLUE)make git-status$(NC)\n\n"

# ═══════════════════════════════════════════════════════════════
# 🔄 GIT-SYNC - Rebase all topic branches from dev
# ═══════════════════════════════════════════════════════════════
# ──── Sync: rebase each branch from origin/dev (local only) ───
# ──── Usage: make git-sync [REPO=name] ────────────────────────
#
# Branches synced: Dynamically detected from ~/Work/<repo>/
# Branches EXCLUDED: dev master rc (protected/base branches)
#
# Override worktrees location:
#   WORKTREES_HOME=~/Projects make git-sync REPO=RaVN
REPO ?= RaVN
git-sync: ## Update all topic branches from dev (local only, default REPO=RaVN)
	@printf "\n"
	@printf "$(CYAN)🔄 git-sync · update all topic branches from dev$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@if [ -z "$(REPO)" ]; then \
		printf "$(RED)  ✗ missing required argument$(NC)\n\n"; \
		printf "  usage:  $(BLUE)make git-sync REPO=RaVN$(NC)\n\n"; \
		printf "  override location:\n"; \
		printf "    $(DIM)WORKTREES_HOME$(NC)  worktrees base dir (default: $(DIM)~/Work$(NC))\n\n"; \
		exit 1; \
	fi
	@WTHOME=$${WORKTREES_HOME:-$$HOME/Work}; \
	REPO_DIR="$$WTHOME/$(REPO)"; \
	if [ ! -d "$$REPO_DIR" ]; then \
		printf "$(RED)  ✗ worktrees directory not found$(NC)\n\n"; \
		printf "  looked in:  $(DIM)$$REPO_DIR$(NC)\n\n"; \
		if [ -n "$$WORKTREES_HOME" ]; then \
			printf "  $(YELLOW)WORKTREES_HOME$(NC) is set to $(DIM)$$WORKTREES_HOME$(NC)\n"; \
			printf "  make sure $(BLUE)$(REPO)$(NC) worktrees exist there\n\n"; \
		else \
			printf "  $(DIM)WORKTREES_HOME$(NC) is not set — defaulting to $(DIM)~/Work$(NC)\n\n"; \
			printf "  if your worktrees are elsewhere, override:\n"; \
			printf "    $(BLUE)WORKTREES_HOME=<path> make git-sync REPO=$(REPO)$(NC)\n\n"; \
			printf "  if the repo is not cloned yet:\n"; \
			printf "    $(BLUE)make git-setup REPO=git@github.com:<user>/$(REPO).git$(NC)\n\n"; \
		fi; \
		exit 1; \
	fi; \
	FAILED=""; \
	for branch_dir in "$$REPO_DIR"/*; do \
		[ -d "$$branch_dir" ] || continue; \
		[ -e "$$branch_dir/.git" ] || continue; \
		branch=$$(basename "$$branch_dir"); \
		if [ "$$branch" = "dev" ] || [ "$$branch" = "master" ] || [ "$$branch" = "rc" ] || [ "$$branch" = "imgbot" ]; then \
			continue; \
		fi; \
		printf "  syncing $(BLUE)$$branch$(NC) ..."; \
		is_dirty=$$(git -C "$$branch_dir" status --porcelain 2>/dev/null); \
		err_log=$$(git -C "$$branch_dir" pull --rebase --autostash origin dev 2>&1); \
		if [ $$? -eq 0 ]; then \
			if [ -n "$$is_dirty" ]; then \
				printf " $(GREEN)✓$(NC) $(DIM)(autostashed)$(NC)\n"; \
			else \
				printf " $(GREEN)✓$(NC)\n"; \
			fi; \
		else \
			if echo "$$err_log" | grep -q "Conflict"; then \
				printf " $(RED)✗  rebase conflict$(NC)\n"; \
			else \
				printf " $(RED)✗  rebase failed: $$(echo "$$err_log" | head -n 1)$(NC)\n"; \
			fi; \
			git -C "$$branch_dir" rebase --abort > /dev/null 2>&1 || true; \
			FAILED="$$FAILED $$branch"; \
		fi; \
	done; \
	printf "\n$(DIM)  dev, master, rc, imgbot: skipped (protected/base branches)$(NC)\n"; \
	if [ -n "$$FAILED" ]; then \
		printf "\n$(RED)  ✗ failed:$$FAILED$(NC)\n"; \
		printf "  resolve conflicts manually with:\n"; \
		for f in $$FAILED; do \
			printf "  $(BLUE)git -C $$REPO_DIR/$$f pull --rebase origin dev$(NC)\n"; \
		done; \
		printf "\n"; \
	else \
		printf "\n$(GREEN)  ✓ all branches synced locally$(NC)\n"; \
	fi
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • verify status: $(BLUE)make git-status$(NC)\n"
	@printf "  • view history:  $(BLUE)make git-log$(NC)\n\n"

# ═══════════════════════════════════════════════════════════════
# 🔄 GIT-DIFF-DEV - Compare dev worktree against rc worktree
# ═══════════════════════════════════════════════════════════════
# ──── Diff: Compare dev against rc using hunk patch ──────────
git-diff-dev: ## Compare dev branch against rc branch
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🔄 git-diff-dev · compare dev against rc$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if git show-ref --quiet refs/heads/rc && git show-ref --quiet refs/heads/dev; then \
		printf "  comparing dev against rc...\n"; \
		if command -v hunk >/dev/null 2>&1; then \
			git diff rc dev | hunk patch; \
		else \
			git diff --color=always rc dev 2>/dev/null || git diff rc dev; \
		fi; \
	else \
		printf "$(RED)  ✗ dev or rc branch not found$(NC)\n"; \
		exit 1; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • compare rc against master:            $(BLUE)make git-diff-rc$(NC)\n"
	@printf "  • compare current worktree against dev: $(BLUE)make git-diff-here$(NC)\n\n"
endif

# ═══════════════════════════════════════════════════════════════
# 🔄 GIT-DIFF-RC - Compare rc branch against master branch
# ═══════════════════════════════════════════════════════════════
# ──── Diff: Compare rc against master using hunk patch ────────
git-diff-rc: ## Compare rc branch against master
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🔄 git-diff-rc · compare rc against master$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if git show-ref --quiet refs/heads/master && git show-ref --quiet refs/heads/rc; then \
		printf "  comparing rc against master...\n"; \
		if command -v hunk >/dev/null 2>&1; then \
			git diff master rc | hunk patch; \
		else \
			git diff --color=always master rc 2>/dev/null || git diff master rc; \
		fi; \
	else \
		printf "$(RED)  ✗ rc or master branch not found$(NC)\n"; \
		exit 1; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • compare dev against rc:               $(BLUE)make git-diff-dev$(NC)\n"
	@printf "  • compare current worktree against dev: $(BLUE)make git-diff-here$(NC)\n\n"
endif

# ═══════════════════════════════════════════════════════════════
# 🔄 GIT-DIFF-HERE - Compare current branch/worktree against dev
# ═══════════════════════════════════════════════════════════════
# ──── Diff: Compare current worktree against dev using hunk ───
git-diff-here: ## Compare current worktree against dev
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🔄 git-diff-here · compare current worktree against dev$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if git show-ref --quiet refs/heads/dev; then \
		printf "  comparing current worktree against dev...\n"; \
		if command -v hunk >/dev/null 2>&1; then \
			git diff dev | hunk patch; \
		else \
			git diff --color=always dev 2>/dev/null || git diff dev; \
		fi; \
	else \
		printf "$(RED)  ✗ dev branch not found$(NC)\n"; \
		exit 1; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • compare dev against rc:    $(BLUE)make git-diff-dev$(NC)\n"
	@printf "  • compare rc against master: $(BLUE)make git-diff-rc$(NC)\n\n"
endif

# ═══════════════════════════════════════════════════════════════
# 💾 GIT-ADD-FUZZY - Interactively stage changes using fzf
# ═══════════════════════════════════════════════════════════════
# ──── Add Fuzzy: Interactive file staging with fzf ───────────
git-add-fuzzy: ## Interactively stage changes using fzf
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)💾 git-add-fuzzy · interactive staging$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if command -v fzf >/dev/null 2>&1; then \
		FILES=$$(git ls-files -m -o --exclude-standard | fzf -m --header="Select files to stage (TAB to multi-select, ENTER to accept)"); \
		if [ -n "$$FILES" ]; then \
			echo "$$FILES" | while IFS= read -r file; do \
				[ -n "$$file" ] && git add "$$file"; \
			done; \
			printf "$(GREEN)  ✓ staged selected file(s)$(NC)\n"; \
		else \
			printf "$(YELLOW)  ⚠  no files selected$(NC)\n"; \
		fi; \
	else \
		printf "$(RED)  ✗ fzf is not installed$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • commit staged changes:  $(BLUE)make git-commit$(NC)\n"
	@printf "  • check repository state: $(BLUE)make git-status$(NC)\n\n"
endif

# ═══════════════════════════════════════════════════════════════
# 📝 GIT-AMEND - Modify last commit
# ═══════════════════════════════════════════════════════════════
# ──── Amend: Amends last commit message or staged files ──────
git-amend: ## Amend the last commit (use MSG="message" to update description)
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)📝 git-amend · modify last commit$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if [ -n "$(MSG)" ]; then \
		$(EXEC) git commit --signoff --amend -m "$(MSG)"; \
	else \
		$(EXEC) git commit --signoff --amend --no-edit; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • push changes to remote: $(BLUE)make git-push$(NC)\n"
	@printf "  • check repository state: $(BLUE)make git-status$(NC)\n\n"
endif

# ═══════════════════════════════════════════════════════════════
# 🗑️  GIT-PRUNE-BRANCHES - Delete all local merged branches
# ═══════════════════════════════════════════════════════════════
# ──── Prune: Automatically removes local merged branches ──────
git-prune-branches: ## Delete all local merged branches
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🗑️  git-prune-branches · remove merged branches$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@MERGED=$$(git branch --merged | sed -E 's|^[*+[:space:]]+||' | grep -E -v '^(dev|master|rc)$$' || true); \
	if [ -n "$$MERGED" ]; then \
		printf "  branches to delete:\n$$MERGED\n\n"; \
		if [ "$$DRY_RUN" = "1" ]; then \
			printf "  ▶ [dry-run] git branch -d $$MERGED\n"; \
		else \
			echo "$$MERGED" | xargs -n 1 git branch -d; \
			printf "$(GREEN)  ✓ merged branches deleted$(NC)\n"; \
		fi; \
	else \
		printf "$(GREEN)  ✓ no merged branches to delete$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • check repository state: $(BLUE)make git-status$(NC)\n\n"
endif

# ═══════════════════════════════════════════════════════════════
# 🔍 GIT-DIFF-FUZZY - Fuzzy select a past commit to diff
# ═══════════════════════════════════════════════════════════════
# ──── Diff Fuzzy: Interactively select a commit to diff ───────
git-diff-fuzzy: ## Fuzzy select a past commit to diff
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🔍 git-diff-fuzzy · select commit to view diff$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if command -v fzf >/dev/null 2>&1; then \
		COMMIT=$$(git log --oneline --color=always | fzf --ansi --no-multi --header="Select commit to diff" | awk '{print $$1}'); \
		if [ -n "$$COMMIT" ]; then \
			git diff "$$COMMIT"^ "$$COMMIT"; \
		fi; \
	elif command -v peco >/dev/null 2>&1; then \
		COMMIT=$$(git log --oneline | peco | awk '{print $$1}'); \
		if [ -n "$$COMMIT" ]; then \
			git diff "$$COMMIT"^ "$$COMMIT"; \
		fi; \
	else \
		printf "$(RED)  ✗ neither fzf nor peco is installed$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • check repository state: $(BLUE)make git-status$(NC)\n"
	@printf "  • view recent history:    $(BLUE)make git-log$(NC)\n\n"
endif

# ═══════════════════════════════════════════════════════════════
# 🔍 GIT-SEARCH - Search commit history
# ═══════════════════════════════════════════════════════════════
# ──── Search: Search history by message or source code changes ─
git-search: ## Search history (use CODE="string" or MSG="query")
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🔍 git-search · search commit history$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if [ -n "$(CODE)" ]; then \
		git log --pretty=format:"  %C(green)%h%C(reset)  %<(50,trunc)%s  %C(dim)%<(15)%ar%C(reset)" -S"$(CODE)"; \
		printf "\n"; \
	elif [ -n "$(MSG)" ]; then \
		git log --pretty=format:"  %C(green)%h%C(reset)  %<(50,trunc)%s  %C(dim)%<(15)%ar%C(reset)" --grep="$(MSG)"; \
		printf "\n"; \
	else \
		printf "$(RED)  ✗ please specify CODE=\"string\" or MSG=\"query\" to search$(NC)\n"; \
		printf "  example: $(BLUE)make git-search CODE=\"foo\"$(NC)\n"; \
		printf "  example: $(BLUE)make git-search MSG=\"chore\"$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • view recent history:    $(BLUE)make git-log$(NC)\n"
	@printf "  • check repository state: $(BLUE)make git-status$(NC)\n\n"
endif
