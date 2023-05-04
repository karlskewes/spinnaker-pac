# From: https://github.com/bitnami-labs/kube-libsonnet/blob/master/tests/Makefile
# LICENSE: Apache2

SHELL=/usr/bin/env bash

LIB_JSONNET=$(wildcard ../*.libsonnet)

# Filenames provide expected testing result (pass|fail)
PASS_JSONNET=$(sort $(wildcard test*pass.jsonnet))
FAIL_JSONNET=$(sort $(wildcard test*fail.jsonnet))
UNIT_JSONNET=$(sort $(wildcard unittest*.jsonnet))
ALL_JSONNET=$(sort $(wildcard *.jsonnet))

# Phony %.diff and golden/*.json targets
PHONY_GOLDEN=$(patsubst %.jsonnet,golden/%.json,$(PASS_JSONNET))
PHONY_DIFF=$(patsubst %.jsonnet,%.diff,$(PASS_JSONNET))

# Phony %.eval-pass and %.eval-fail targets
PHONY_EVAL_PASS=$(patsubst %.jsonnet,%.eval-pass,$(PASS_JSONNET))
PHONY_EVAL_FAIL=$(patsubst %.jsonnet,%.eval-fail,$(FAIL_JSONNET))

local-tests: req-jsonnet unittests lint $(PHONY_EVAL_PASS) $(PHONY_EVAL_FAIL) diff

# NB: unittest jsonnet files are also covered by eval-pass and diff targets,
#     called out here for convenience
unittests:
	jsonnet $(UNIT_JSONNET)

lint: req-jsonnetfmt
	@set -e; errs=0; \
        for f in $(ALL_JSONNET) $(LIB_JSONNET); do \
	  if ! jsonnetfmt --test -- $$f; then \
	    echo "FAILED lint: $$f" >&2; \
	    errs=$$(( $$errs + 1 )); \
	  fi; \
	done; \
	if [ $$errs -gt 0 ]; then \
	  echo "NOTE: if the 'lint' target fails, run:"; \
	  echo "      $(MAKE) fix-lint lint"; \
	  exit 1; \
	fi

diff: diff-help $(PHONY_DIFF)

%.diff: %.jsonnet
	diff -u golden/$(*).json <(jsonnet $(<))

%.eval-pass: %.jsonnet
	@echo "INFO: must PASS: $(<)"
	@(jsonnet $(<) > /dev/null)
	@echo "OK[PASS]: $(<)"

%.eval-fail: %.jsonnet
	@echo "INFO: must FAIL: $(<)"
	@echo -n "| "; (jsonnet $(<) > /dev/null) 2>&1 | grep RUNTIME.ERROR
	@echo "OK[FAIL]: $(<)"


golden/%.json: %.jsonnet
	jsonnet $(<) > $(@)

diff-help:
	@echo "NOTE: if the 'diff' target fails, review output and run:"
	@echo "      $(MAKE) gen-golden diff"
	@echo

fix-lint: req-jsonnetfmt
	@set -e; \
	for f in $(ALL_JSONNET) $(LIB_JSONNET); do \
	  echo jsonnetfmt -- $$f; \
	  jsonnetfmt -- $$f; \
	done

req-%:
	@which $(*) >/dev/null && exit 0; echo "ERROR: '$(*)' is required in PATH"; exit 1

gen-golden: $(PHONY_GOLDEN)

.PHONY: unittests lint eval-pass eval-fail validate diff %.eval-pass %.evail-fail %.diff golden/%.json diff-help fix-lint gen-golden
