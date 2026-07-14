.DEFAULT_GOAL := help

RAVN_DIR := .
SCRIPTS_DIR := $(RAVN_DIR)/Scripts

CYAN := \033[0;36m
NC := \033[0m

include make/dev.mk
