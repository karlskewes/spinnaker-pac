# Spinnaker Pipelines as Code

An opinionated framework for managing Spinnaker Applications, Pipelines and
Projects as Code using Jsonnet and the [spin-libsonnet](https://github.com/karlskewes/spin-libsonnet)
library.

## Target audience

Designed for Platform teams operating Spinnaker to codify infrastructure
concerns whilst providing an application and pipeline DSL for Product teams to
self-serve.

This project expects the Platform team(s) to own a monorepo containing all
jsonnet and review pull requests made by Product teams for their applications.
Jsonnet enables off-roading through composition which is both powerful and
potentially undesirable. For example, targeting a different AWS account or
Kubernetes cluster.

## Goals

- Language - user focused DSL - `artifacts`, `environments`, ordering
- Consistency - deploy any application with the same pipeline building blocks
- Programmatic - no manual clicking through UI
- Lightweight - easy for user to onboard new app with minimal jsonnet

## The deploy pipeline

The [deploy.jsonnet](./deploy.jsonnet) pipeline is the special sauce and also
where the complexity lies.

It provides a golden path that is easy to onboard to whilst supporting ad-hoc
pipeline extensions to cope with the messy reality of codifying business processes.

The [example](./example/) structure generates a single Spinnaker pipeline per
Spinnaker application.

I believe that a single pipeline deploying through any and all environments to
production is preferable.

A single pipeline is simpler to operate, results in less drift across
environments if more than one, becomes familiar across teams and departments,
accomplishes shorter time-to-value and lower failure rates.

A single pipeline does put tension on processes because new artifact versions
can pile up waiting for the existing pipeline to complete.

That all said, you can add your own pipeline templates and wire up applications
to use them.

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
