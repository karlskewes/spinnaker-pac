#### Main constraints

- Spinnaker schema dictates how final json must be. This is obvious but a real
  challenge and not something we can change!
- `stages` must fan in/out for prod accounts/etc.
- `expectedArtifacts` define docker/gitlab/s3 files.
- `stages` require keys from associated `expectedArtifacts` they are deploying.
- `expectedArtifacts` don't have all the keys (deploy order, stage type) to
  make them a source to work from once built.

#### Options

1. (selected option) - loop artifacts & accounts once and in single pass build
   both expectedArtifacts and stages
2. add required metadata to hidden keys <key>:: in expectedArtifact and then
   loop expectedArtifacts (order + stage type) ??
3. do multiple loops like the old sponnet `deploy.jsonnet` pipeline.
4. heavy string format conventions and parsing of expectedArtifacts

### The list:

- we wanted to refactor the DSL/interface for developers (myapp.jsonnet) and
  the desired result didn't seem achievable.
- upstream sponnet "fluent interface / builder pattern" is verbose and painful
  to work with.
- the API discoverability of builder pattern is nice but insufficient because
  Deck or Orca may require more than one key to configure a pipeline feature
  and this is not knowable from looking at sponnet.
- duplicating all pipeline schema into sponnet requires effort. Similar
  challenges exist with Helm. Maintaing basic stage json and relying on jsonnet
  composition to extend pipeline stages is simpler.
- lack of opinions (default calculated key:values) results in additional work.
  Opinions here may not suit everyone but are overridable with `stageJson`.
- example pipeline requires multiple different sections to build Spinnaker
  objects in isolation and then when fan in/out for accounts led to:
  - loop per object per account/etc.
  - 635 LOC and not at all DRY.
  - difficultly doing composition (`+` into) stages and without a lot more lines.

## Adding a new application

1. Go to project

   ```sh
   cd platform/
   ```

2. Copy another application file to use as a base

   ```sh
   cp spinnaker.jsonnet myapp.jsonnet
   ```

3. Edit your new app file

   ```sh
   vim myapp.jsonnet
   ```

4. Add new app to projects `applications: {}` map because jsonnet does not
   support dynamic/computed imports.
   Enclose hyphenated keys in single quotes, eg: `'nginx-ingress': (import...)`

   ```sh
   vim project.jsonnet
   ```

   ```jsonnet
   applications: {
     myapp: (import './myapp.jsonnet'),  // add your app like this
   }
   ```

5. Render jsonnet to json

   ```sh
   make clean build
   ```

6. Deploy to spinnaker

   ```sh
   make deploy-all
   ```

## Library DSL

| term               | common use case                             | purpose                                                                                      |
| :----------------- | :------------------------------------------ | :------------------------------------------------------------------------------------------- |
| stageBlockOrdering | `['staging','production']`                  | ordering of stage blocks                                                                     |
| stageBlock         | environment, e.g: `staging` or `production` | collection of stages, can be more than one                                                   |
| stageJson          | wait stage                                  | custom stage JSON fields or whole stage object. workaround lack of object comprehension      |
| stageOrder         | 1 or 2 or 100 (int)                         | position of stage in the stageBlock, fan in/out by using same number for more than one stage |

### Spinnaker Object Tree

- Project(s)
  - Application(s) (may also be at root level, not under any `Project`)
    - Pipeline(s)
    - Infrastructure - deployed app/lb/fw instances

### Spinnaker Applications

Spinnaker Applications must be unique. One convention is to prefix applications
with the Spinnaker Project name. For example:

- myapp-redis-exporter
- spinnaker-redis-exporter
- spinnaker-mysql-exporter

### EC2

#### Naming convention

The easiest way to support deploying to more than one environment or region is
to specify a naming convention.

This then enables disparate tools such as Terraform, Jsonnet, Spinnaker to rely
on the convetion without building complicated "mapping" or "discovery" systems.

For example, Terraform code specifies resources per region with the naming
convention: `<company>-<env>-<region>-<appname>`

Example:

- Jsonnet: `$._config.serverGroup.myapp: { ... }`
- AWS IAM: Instance Profile = `mycompany-stg-ap-southeast-2-myapp`
- AWS Security Group: `mycompany-stg-ap-southeast-2-myapp`
- Kubernetes yaml: `/kubernetes/stg/ap-southeast-2/myapp.yaml`
