# Exampleco jsonnet render and upsert Spinnaker

# Make defaults
# Use commonly available shell
SHELL :=  bash
# Fail if piped commands fail - critical for CI/etc
.SHELLFLAGS := -o errexit -o nounset -o pipefail -c

OUTPUT_DIR := manifests

.PHONY: all
all: help

.PHONY: clean
clean:  ## Removes any manifests from previous builds
	@for dir in $(shell find * -type d -path '*/$(OUTPUT_DIR)'); do \
		echo "Deleting old output directory $${dir}"; \
		rm -rf "$${dir}"; \
	done

.PHONY: dep
dep:  ## Install dependencies
	go install github.com/google/go-jsonnet/cmd/jsonnet@latest
	go install github.com/google/go-jsonnet/cmd/jsonnetfmt@latest
	go install github.com/google/go-jsonnet/cmd/jsonnet-lint@latest
	go install github.com/spinnaker/spin@latest
	go install github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest

# HACK - compile twice because can't seem to get exit error with jsonnet -m...

.PHONY: build
build: ## Generate JSON manifests for `spin save`
	@jsonnet --version
	@export failed=0; \
	for dir in $(shell find * -type d | \
		grep -v '$(OUTPUT_DIR)'); do \
			echo "Building $${dir}"; \
			pushd "$${dir}" > /dev/null || export failed=1; \
			mkdir -p $(OUTPUT_DIR); \
			for f in $$(find * -name '*.jsonnet'); do \
				jsonnet "$${f}" > /dev/null || export failed=1; \
				jsonnet \
					--multi $(OUTPUT_DIR) \
					"$${f}" | \
					xargs -I{} sh -c 'cat {} > {}.json; rm -f {}' -- {} \
					|| export failed=1; \
			done; \
			popd > /dev/null || export failed=1; \
	done; \
	if [ "$$failed" -eq 1 ]; then \
		exit 1; \
	fi

.PHONY: deploy-applications
deploy-applications: deploy-application ## Deploy application manifest(s) to Spinnaker - default all, else use 'FILE=path/to/file.json'

.PHONY: deploy-pipelines
deploy-pipelines: deploy-pipeline ## Deploy pipeline manifest(s) to Spinnaker - default all, else use 'FILE=path/to/file.json'

.PHONY: deploy-projects
deploy-projects: deploy-project ## Deploy project manifest(s) to Spinnaker - default all, else use 'FILE=path/to/file.json'

.PHONY: deploy-all
deploy-all: deploy-applications deploy-pipelines deploy-projects ## Deploy all applications, pipelines, projects

deploy-%:
	@$(SPIN) --version
	@if [ -n "$(FILE)" ]; then \
		if [ -f "$(FILE)" ]; then \
			echo "Saving $(@:deploy-%=%) $(FILE) ..."; \
			$(SPIN) $(@:deploy-%=%) save --file $(FILE); \
			exit 0; \
		else \
			echo "File $(FILE) not found."; \
			exit 1; \
		fi; \
	else \
		for file in $(shell find * -type f -path '*/$(OUTPUT_DIR)/*' -name '$(@:deploy-%=%)-*'); do \
			echo "Saving $(@:deploy-%=%) $${file} ..."; \
			$(SPIN) $(@:deploy-%=%) save --file $${file}; \
		done; \
	fi

.PHONY: test
test: ## Test for rendering, formatting and linting errors
	@jsonnet --version
	@export failed=0; \
	for f in $$(find * -name '*.jsonnet' -o -name '*.libsonnet'); do \
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
