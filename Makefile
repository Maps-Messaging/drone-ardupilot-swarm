SHELL := /usr/bin/env bash
VERSION := $(shell cat VERSION)
DIST_DIR := dist
ARCHIVE := $(DIST_DIR)/ardupilot-swarm-$(VERSION).tar.gz
DEB := $(DIST_DIR)/ardupilot-swarm_$(VERSION)_all.deb
NEXUS_REPOSITORY ?= maps-drone-repo

.PHONY: validate dist deb release clean install update uninstall

validate:
	./scripts/validate.sh

dist: validate
	mkdir -p $(DIST_DIR)
	tar \
		--exclude='./$(DIST_DIR)' \
		--exclude='./build' \
		--exclude='./.git' \
		--transform='s,^\.,ardupilot-swarm-$(VERSION),' \
		-czf $(ARCHIVE) .
	@echo "Created $(ARCHIVE)"

deb: validate
	./packaging/build-deb.sh

release: deb
	./packaging/upload-deb.sh "$(NEXUS_REPOSITORY)" "$(DEB)"

clean:
	rm -rf $(DIST_DIR) build

install:
	./install.sh

update:
	./update.sh

uninstall:
	./uninstall.sh
