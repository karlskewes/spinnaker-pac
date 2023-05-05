# One pipeline to rule them all

An opinionated framework for managing Spinnaker Applications, Pipelines and
Projects as Code using [spin-libsonnet](https://github.com/karlskewes/spin-libsonnet).

## Goals / Constraints

Designed for Platform teams operating Spinnaker to codify infrastructure
concerns whilst providing an application and pipeline DSL for Product teams to
self-serve.

This project expects the Platform team(s) to own a monorepo containing all
jsonnet and review pull requests made by Product teams for their applications.
Jsonnet enables off-roading through composition which is both powerful and
potentially undesirable. For example, targeting a different AWS account or
Kubernetes cluster.

Goals:

- Language - custom DSL that is user focused - `artifacts`, `environments`,
  ordering
- Consistency - user can deploy any supported application with the same pipeline
  format
- Programmatic - no manual clicking through UI
- Lightweight - easy for user to onboard new app with minimal jsonnet

## The deploy pipeline

The file [deploy.jsonnet](./deploy.jsonnet) provides all key functionality in
this repository.

It supports generating a single Spinnaker pipeline per Spinnaker application.

I believe that a single pipeline deploying through any and all environments to
production is preferable.

A single pipeline is simpler to operate, results in less drift across
environments if more than one, becomes familiar across teams and departments,
accomplishes shorter time-to-value and lower failure rates.

A single pipeline does put tension on processes because new artifact versions
can pile up waiting for the existing pipeline to complete.

That all said, you can add your own pipeline template files and wire up
applications to use them.

## Getting started

Whether you're in a Platform team operating Spinnaker or in a Product team
using Spinnaker as a customer, start with the [TUTORIAL.md](./TUTORIAL.md).

This will give you a basic understanding of working with jsonnet and the key
features you might need.

## Example implementation

After exploring the tutorial have a browse through the [example/](./example/)
directory.

```
cd example/
```

Render all jsonnet to json:

```
make build
```

Deploy all applications, pipelines and projects:

```
make deploy-all
```

Other make targets:

```
$ make
build                          Generate JSON manifests for `spin save`
clean                          Removes any manifests from previous builds
dep                            Install dependencies
deploy-all                     Deploy all applications, pipelines, projects
deploy-applications            Deploy application manifest(s) to Spinnaker - default all, else use 'FILE=path/to/file.json'
deploy-pipelines               Deploy pipeline manifest(s) to Spinnaker - default all, else use 'FILE=path/to/file.json'
deploy-projects                Deploy project manifest(s) to Spinnaker - default all, else use 'FILE=path/to/file.json'
test                           Test for rendering, formatting and linting errors
```

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md)
