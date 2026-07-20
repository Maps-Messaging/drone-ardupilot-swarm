SHELL := /usr/bin/env bash
VERSION := $(shell cat VERSION)
DIST_DIR := dist
ARCHIVE := $(DIST_DIR)/ardupilot-swarm-$(VERSION).tar.gz

.PHONY: validate dist clean install update uninstall

validate:
	./scripts/validate.sh

dist: validate
	mkdir -p $(DIST_DIR)
	tar \
		--exclude='./$(DIST_DIR)' \
		--exclude='./.git' \
		--transform='s,^\.,ardupilot-swarm-$(VERSION),' \
		-czf $(ARCHIVE) .
	@echo "Created $(ARCHIVE)"

clean:
	rm -rf $(DIST_DIR)

install:
	./install.sh

update:
	./update.sh

uninstall:
	./uninstall.sh
