.DEFAULT_GOAL := help

RAVN_DIR := .
SCRIPTS_DIR := $(RAVN_DIR)/Scripts

RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
CYAN := \033[0;36m
DIM := \033[2m
NC := \033[0m

include make/dev.mk
include make/git.mk
include make/aliases.mk
