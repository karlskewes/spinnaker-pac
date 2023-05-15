# Spinnaker as Code Tutorial

This tutorial aims to take you through the mechanisms available to customize
applications and pipelines.

This tutorial assumes that some team has setup Spinnaker Kubernetes accounts,
Gitlab & Docker artifacts sources for you.

Table of Contents:

- [Getting Setup](#getting-setup)
- [Changing artifact names](#changing-artifact-names)
- [Changing stage ordering](#changing-stage-ordering)
- [Changing stage block ordering](#changing-stage-block-ordering)
- [Target account selection](#target-account-selection)
- [Injecting custom stages](#injecting-custom-stages)
- [Adding notifications](#adding-notifications)
- [Creating file structure](#creating-file-structure)
- [Adding your own pipelines](#adding-your-own-pipelines)
- [Extending deploy.jsonnet](#extending-deploy.jsonnet)

## Getting Setup

Install `jsonnet`, `jb` and `spin` CLI dependencies using Go.

```
make dep
```

We will use the end-to-end test file as our example configuration. It's long
but is self-contained. Later we will discuss file structure.

Create a new working directory and copy this file to it.

```
mkdir tutorial
cp tests/test-e2e.pass.jsonnet tutorial/example.jsonnet
cd tutorial
```

Confirm that you can compile to Spinnaker json.

```
jsonnet example.jsonnet > example-default.json
```

View the file in your text editor or similar. The specifics are not important
at this stage, but the file must have renderered.

Note: The JSON contains both Spinnaker application and pipeline JSON so we
can't copy it into the Spinnaker UI.

```
$ head example-default.json
{
   "application-myapp": {
      "cloudProviders": "kubernetes",
      "description": "myapp",
      "email": "me@example.com",
      "name": "myapp",
      "permissions": {
         "EXECUTE": [
            "product team",
            "site reliability engineering"
```

As we progress we will be modifying `example.jsonnet` and comparing the output.

## Changing artifact names

Open `example.jsonnet` and scroll to the `Example Application` section at the
bottom (jsonnet is lazily evaluated and last specified value wins).

We have 4 artifacts configured.

1. Docker image (`type: 'docker'`) with repository `myorg/myapp`
2. Gitlab Job Manifest yaml (`type: 'gitlab'`) as `infra/myapp-setup.yaml`
3. Gitlab Deploy Manifest yaml (`type: 'gitlab'`) as `infra/myapp.yaml`
4. Gitlab Job Manifest yaml (`type: 'gitlab'`) as
   `infra/myapp-integration-tests-job.yaml`

The `artifacts: { <key> ...` is a repo for Docker and a file path in our Gitlab
repo.

The actual Docker Registry and Gitlab instance is defined further up in the
file but we will assume the defaults are fine for now.

1. Change the Docker image to `example/api-gateway`.
2. Change the Gitlab yaml file `infra/myapp.yaml` to `infra/api-gateway.yaml`
3. Save the file.

Render the jsonnet and save the output to a different file so we can compare.

```
jsonnet example.jsonnet > example1.json

$ diff example.json example1.json | head
29,30c29,30
<                "name": "index.docker.io/myorg/myapp",
<                "reference": "index.docker.io/myorg/myapp",
---
>                "name": "index.docker.io/myorg/api-gateway",
>                "reference": "index.docker.io/myorg/api-gateway",
33,34c33,34
<             "displayName": "index.docker.io/myorg/myapp",
<             "id": "index.docker.io/myorg/myapp",
---
```

We can see Docker image referenced in the JSON has changed.

If we remove the `| head` from our query we can also see references to
`infra/myapp.yaml` have changed to `infra/api-gateway.yaml`.
There appears to be other changes but they are due to jsonnet ordering arrays
in the output and do not affect Spinnaker.

The artifacts name changes introduces us to some conventions in this jsonnet
code.

1. A single Spinnake pipeline may deploy to more than one target environment or
   substrate. The `example.jsonnet` file has a 6 clusters specified.
2. It's expected that we have a consistent repository file structure that we
   can rely on when generating Spinnaker json client side. We'll talk more
   about accounts later, but if our YAML is in a monorepo then we can define
   a `path` key for the Kubernetes account.

## Changing stage ordering

Defining stage order is a first class concept.

In `example.jsonnet` the application deploy process is:

1. Run setup job.
2. Deploy application.
3. Run integration test job.

Each step requires a different artifact so there are three corresponding
`type: 'gitlab'` artifacts defined with appropriate `stageOrder: 1|2|3` value.

Key details:

- `stageOrder` is an integer type.
- higher numbers schedule later in the Spinnaker Pipeline, ie: artifacts with
  `stageOrder: 2` execute after artifacts with `stageOrder: 1`
- any artifacts with matching `stageOrder` values execute in the same
  'column'/place, enabling fan out and fan in behaviour.

You may be wondering about progressing the same artifact through environments
(staging -> production), hint `stageBlock`. That's coming up in the next
section.

For the sake of learning let's run the `infra/myapp-setup.yaml` job after the
integration tests.

Make the necessary changes to `example.jsonnet` to look like this:

```
      'infra/myapp-setup.yaml': {
        type: 'gitlab',
        stageOrder: 4,  // changing this value from 1 to 4
        stageType: 'runJobManifest',
      },
```

Render the json again and compare.

```
jsonnet example.jsonnet > example2.json

diff example1.json example2.json | grep -n1 requisiteStageRefIds

11-259,261c257
12:<             "requisiteStageRefIds": [
13-<                "JOB :: stg-us-east-1-cluster-admin :: infra/myapp-setup.yaml"
--
15----
16:>             "requisiteStageRefIds": [ ],
17-296c292,293
--
27-331c329,331
28:<             "requisiteStageRefIds": [ ],
29----
30:>             "requisiteStageRefIds": [
31->                "JOB :: stg-us-east-1-cluster-admin :: infra/myapp-integration-tests-job.yaml"
```

`requisiteStageRefIds` is Spinnakers json key for "preceding stages id's", i.e:
what comes before the current stage.

Without diving into the new `example2.json` we can see that there have been
changes. Specifically `myapp-setup.yaml` deploy stages now rely on the
`infra/myapp-integration-tests-job.yaml` stage.

If you're familiar with the Spinnaker json feel free to have a look at the
bottom of the file.

## Changing stage block ordering

We saw above that we can order stages. Sometimes we want to execute the same
stage(s) but against two or more different targets sequentially.

For example, deploy all artifacts to `staging` and then deploy/promote the same
artifacts to `production`, all in a single pipeline.

Enter the `stageBlock`. In our example above `staging` and `production` are
each a `stageBlock`. You can define your own `stageBlock` names.

Our `example.jsonnet` file already has the `staging` and `production`
`stageBlocks` configured.

```
grep 'stageBlock' example.jsonnet | head

      // stageBlock: null, // most apps go everywhere
    stageBlockOrdering: ['staging', 'production'],
        stageBlock: 'staging',
    // Looped in artifact and deploys, with selector labels (stageBlock, team, etc) for deciding if use that account
      { name: 'prd-global-ec2-admin', regions: ['ap-southeast-2', 'us-east-1'], keyPair: 'example-prd-global-spinnaker', labels: { stageBlock: 'production', cloudProvider: 'aws', cloud: 'aws', team: 'sre', infra: true } },
      { name: 'prd-ap-southeast-2-cluster-admin', path: 'prd/ap-southeast-2', labels: { stageBlock: 'production', cloudProvider: 'kubernetes', cloud: 'aws', team: 'sre', infra: true, region: 'ap-southeast-2' } },
      { name: 'prd-us-east-1-cluster-admin', path: 'prd/us-east-1', labels: { stageBlock: 'production', cloudProvider: 'kubernetes', cloud: 'aws', team: 'sre', infra: true, region: 'us-east-1' } },
      { name: 'stg-us-east-1-cluster-admin', path: 'stg/us-east-1', labels: { stageBlock: 'staging', cloudProvider: 'kubernetes', cloud: 'aws', team: 'sre', infra: true, region: 'us-east-1' } },
      { name: 'stg-global-ec2-admin', regions: ['us-east-1'], keyPair: 'example-stg-global-spinnaker', labels: { stageBlock: 'staging', cloudProvider: 'aws', cloud: 'aws', team: 'sre', infra: true } },
      { name: 'prd-global-ec2-product-edit', regions: ['ap-southeast-2', 'us-east-1'], keyPair: 'example-prd-global-spinnaker', labels: { stageBlock: 'production', cloudProvider: 'aws', cloud: 'aws', team: 'product', product: true } },
```

The key line is this one:

```
grep 'stageBlock' example.jsonnet | head

    stageBlockOrdering: ['staging', 'production'],
```

Here we are saying our `stageBlocks` are `staging` and `production` and they
occur in the array's order, `staging` first followed by `production`.

We've chosen to use a term commonly used for `environments` as our stage block
names but it could be anything that suits, for example:

```
    stageBlockOrdering: ['staging', 'canary', 'production'],
```

or:

```
    stageBlockOrdering: ['blue', 'green', 'red', 'black'],
```

You may have noticed that when we were changing the example applications
artifacts and stage order in previous sections there was a
`labels: { stageBlock: 'staging' }` key on one of the artifacts.

This is one way we can do per-artifact overrides and we will see more of this
label matching later.

Let's reverse the stage block order in `example.jsonnet` like this.

```
grep 'stageBlockOrdering' example.jsonnet

    stageBlockOrdering: ['production', 'staging'],
```

Save, compile and diff again, noting the chages to `requisiteStageRefIds`:

```
jsonnet example.jsonnet > example3.json

diff example2.json example3.json

223,225c223
<             "requisiteStageRefIds": [
<                "Manual Judgment"
<             ],
---
>             "requisiteStageRefIds": [ ],
240,242c238
<             "requisiteStageRefIds": [
<                "Manual Judgment"
<             ],
---
>             "requisiteStageRefIds": [ ],
257c253,256
<             "requisiteStageRefIds": [ ],
---
>             "requisiteStageRefIds": [
>                "JOB :: prd-ap-southeast-2-cluster-admin :: infra/myapp-setup.yaml",
>                "JOB :: prd-us-east-1-cluster-admin :: infra/myapp-setup.yaml"
>             ],
```

You can dive into the json to compare more specifically if you like.

## Target account selection

Spinnaker platform teams configure Spinnaker Provider Account's with the
cloud provider IAM credentials and a map of `labels: {}`.

You can select what Spinnaker Provider Account to deploy to on a per team,
application or artifact basis by ensuring your `labels: {}` match the Provider
account `labels: {}`.

If you are familiar with Kubernetes `nodeAffinity` and `taints|tolerations`
then this is similar.

Some example labels:

- `environment: 'staging' // or 'production'`
- `team: 'product' // or 'sre'` for authz
- `platform: 'kubernetes' // or 'ec2'` for target
- `teamXYZ: true` (bool) for Project selection
- `region: ap-southeast-2 // or 'us-east-1'`

We can work in two directions:

1. Application requirements (implemented):
   - all app labels must match on Spinnaker `account` labels
   - kubernetes examples: Pod selects Node, i.e: nodeAffinity
2. Account requirements (not implemented)
   - all Spinnaker `account` labels must match app labels
   - k8s example: Node repels Pods, i.e: taints/tolerations

You can define some default behaviour, for example:

```
    // Application selectors -- all must match account labels
    labels: {
      // stageBlock: null, // don't set, apps deployed to staging and production
      // leaky abstraction - Spinnaker 'cloudProvider' dictates available
      // pipeline stages, eg: Deploy (EC2) or DeployManifest (K8S)
      cloudProvider: 'kubernetes',  // aws || kubernetes
      team: null, // least privilege principle, require decision in project/app
    },
```

Let's target Product "team" accounts instead of SRE "team" accounts in
`example.jsonnet`:

```
grep -A3 'labels+:' tests/test-e2e.pass.jsonnet

    labels+: {
      team: 'product', // was 'sre'
      product: true, // was 'sre: true'
    },

```

Save, compile and diff again, noting the chages to `account` and other fields:

```
jsonnet example.jsonnet > example4.json

diff example3.json example4.json

215c215
<             "account": "stg-us-east-1-cluster-admin",
---
>             "account": "stg-us-east-1-product-edit",
218c218
<             "credentials": "stg-us-east-1-cluster-admin",
---
>             "credentials": "stg-us-east-1-product-edit",
```

## Injecting custom stages

For this example, imagine we want to add integration tests to run
after our `Deploy Manifest` stage. We can add an item to the
`customStages: {}` object with the relevant fields. For now we will use
a `wait` stage to keep it simple.

```
    customStages+: {
      triggerIntegrationTests: { // key name can be anything
        labels: { stageBlock: 'staging' }, // optional, only run in "staging"
        stageJson: spin.wait(), // any Spinnaker stage json copied from Deck or otherwise
        stageOrder: 4,
      },
    },
```

## Adding notifications

TODO

## Creating file structure

Jsonnet supports composition so you can put team/department/company defaults
into a jsonnet files and import the appropriate file as required.

A useful directory structure might look like:

```
./departmentA/app1.jsonnet  # a Spinnaker Application
./departmentA/app2.jsonnet
./departmentA/project-defaults.jsonnet # shared config for department
./departmentA/project.jsonnet # a Spinnaker Project
./departmentA/
./departmentB/...
./departmentC/...
./config-defaults.jsonnet # company defaults, Kubernetes cluster, artifacts
```

See the working [example/](./example/) and included [Makefile](./example/Makefile)
for completing common tasks.

## Adding your own pipelines

TODO

## Extending deploy.jsonnet

TODO
