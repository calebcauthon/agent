SHELL := /bin/bash

SH_FILES := $(shell git ls-files '*.sh')

.PHONY: check prepush lint keys

check: lint keys

prepush: check

lint:
	@if [ -z "$(SH_FILES)" ]; then \
		echo "No shell scripts to lint."; \
	elif command -v shellcheck >/dev/null 2>&1; then \
		shellcheck $(SH_FILES); \
	elif command -v docker >/dev/null 2>&1; then \
		docker run --rm -v "$(PWD):/mnt" -w /mnt koalaman/shellcheck:stable $(SH_FILES); \
	else \
		echo "shellcheck is not installed."; \
		echo "Install it with: brew install shellcheck"; \
		exit 1; \
	fi

keys:
	@echo "Scanning tracked and unignored files for common secret/key patterns..."
	@PATTERN='(-----BEGIN (RSA |DSA |EC |OPENSSH |PGP )?PRIVATE KEY-----|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|ghp_[0-9A-Za-z]{36,}|github_pat_[0-9A-Za-z_]{80,}|glpat-[0-9A-Za-z_-]{20,}|sk-ant-[0-9A-Za-z_-]{20,}|sk-[A-Za-z0-9]{32,})'; \
	TMP=$$(mktemp); \
	git ls-files -z --cached --others --exclude-standard \
		| xargs -0 grep -nIE "$$PATTERN" >"$$TMP" 2>/dev/null || true; \
	if [ -s "$$TMP" ]; then \
		echo "Potential secret(s) found:"; \
		cat "$$TMP"; \
		rm -f "$$TMP"; \
		exit 1; \
	else \
		rm -f "$$TMP"; \
		echo "No common secret/key patterns found."; \
	fi
