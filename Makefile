# Launch this workflow through Crucible in Linux/WSL.
IGNY ?= igny
IGNY_ENV ?= hls-sobel
IGNY_SCRIPT = $(IGNY) run script --env $(IGNY_ENV)
.DEFAULT_GOAL := help
.NOTPARALLEL:
.PHONY: help setup check sed build run smoke report preflight hls core apb synth mapped physical stream routed reference physical-verify controls provenance

help:
	@echo "igny run --env $(IGNY_ENV) make run - execute the complete experiment and independent checks"
	@echo "igny run --env $(IGNY_ENV) make build - prepare the project build artifacts"
	@echo "igny run --env $(IGNY_ENV) make smoke - verify existing results; does not rebuild"
	@echo "igny run --env $(IGNY_ENV) make setup - prepare pinned project-local observer dependencies"
	@echo "igny run --env $(IGNY_ENV) make check - check Python observer imports"
	@echo "igny run --env $(IGNY_ENV) make sed - normalise public shell inputs to LF"
	@echo "igny run --env $(IGNY_ENV) make report - print generated result summaries"
	@echo "igny run --env $(IGNY_ENV) make preflight - review public package paths, links and hashes"

setup:
	$(IGNY_SCRIPT) scripts/demo_info.py -- setup

check:
	$(IGNY_SCRIPT) scripts/demo_info.py -- check

sed:
	$(IGNY_SCRIPT) scripts/demo_info.py -- normalise

report:
	$(IGNY_SCRIPT) scripts/demo_info.py -- report

preflight:
	$(IGNY_SCRIPT) scripts/preflight_git.py

build: sed reference hls

run: sed check build core apb synth mapped physical stream routed physical-verify controls provenance smoke

hls:
	$(IGNY_SCRIPT) scripts/run.sh -- hls

core:
	$(IGNY_SCRIPT) scripts/run.sh -- core

apb:
	$(IGNY_SCRIPT) scripts/run.sh -- apb

synth:
	$(IGNY_SCRIPT) scripts/run.sh -- synth

mapped:
	$(IGNY_SCRIPT) scripts/run.sh -- mapped

physical:
	$(IGNY_SCRIPT) scripts/run.sh -- physical

stream:
	$(IGNY_SCRIPT) scripts/run.sh -- stream

routed:
	$(IGNY_SCRIPT) scripts/run.sh -- routed

reference:
	$(IGNY_SCRIPT) scripts/reference.sh

physical-verify:
	$(IGNY_SCRIPT) scripts/physical_verify.sh

controls:
	$(IGNY_SCRIPT) scripts/controls.sh

provenance:
	$(IGNY_SCRIPT) scripts/provenance.py

smoke:
	$(IGNY_SCRIPT) scripts/demo_info.py -- verify
