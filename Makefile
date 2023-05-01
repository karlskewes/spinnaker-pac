# Spinnaker jsonnet

# Make defaults
# Use commonly available shell
SHELL :=  bash
# Fail if piped commands fail - critical for CI/etc
.SHELLFLAGS := -o errexit -o nounset -o pipefail -c

.PHONY: all
all: help

.PHONY: dep
dep:  ## Install dependencies
	go install github.com/google/go-jsonnet/cmd/jsonnet@latest
	go install github.com/google/go-jsonnet/cmd/jsonnetfmt@latest
	go install github.com/google/go-jsonnet/cmd/jsonnet-lint@latest
	go install github.com/spinnaker/spin@latest
	go install github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest
	jb install

.PHONY: test
test: ## Test for rendering, formatting and linting errors
	@jsonnet --version
	@export failed=0; \
	for f in $$(find * -name '*.jsonnet' -o -name '*.libsonnet' | grep -v '\(tests/\|vendor/\)'); do \
		echo "Testing $${f}"; \
		jsonnet "$${f}" > /dev/null || export failed=1; \
		jsonnetfmt --test "$${f}" || export failed=1; \
		jsonnet-lint "$${f}" || export failed=1; \
	done; \
	if [ "$$failed" -eq 1 ]; then \
		exit 1; \
	fi

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
