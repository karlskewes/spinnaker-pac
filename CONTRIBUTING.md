# Contributing

Pull requests are most welcome.

## Behaviour table

Some non-obvious behaviours:

`Deck` is the Spinnaker frontend service.

| Resource         | Deck shows | Deck json | jsonnet json        | result                             |
| :--------------- | :--------- | :-------- | :------------------ | :--------------------------------- |
| `Security Group` | name (id)  | id        | name                | Spinnaker maps from `name` to `id` |
| `AMI ID`         | N/A        | N/A       | `amiName: <ami-id>` | Spinnaker uses desired ami         |

## Spinnaker JSON Schema

### Application Schema

Application schema includes the application name, owner email address plus some
defaults for the team, company, platform.

### Pipeline Schema

In the Spinnaker pipeline JSON the keys `artifacts`, `stages`, `triggers` are
all root level objects.

This makes it tricky when we need to add items per environments/regions/etc and
they need to reference an `artifact` back up in the root tree.

```jsonnet
{
    artifacts: [
    // git manifest
    // docker repo
    // s3 file
    ]
    stages: [
    // deploy with artifact, except artifact in .artifacts[]
    // manual judgment
    ]
    triggers: [
    // docker trigger with docker artifact constraint matching .artifacts[x]
    // git trigger with git artifact
    // webhook with s3, custom, embedded artifact
    ]
}
```

Options:

1. Loop whole thing and stamp out everything in one go. We do this but it
   requires going to an intermediate representation and lazy evaluation. We
   call this `sir:` (Spinnaker IR) in the code.
2. Loop each section. This approach works with the upstream `sponnet` examples.
   It duplicates logic and is difficult to do composition like adding custom
   json to a stage or injecting custom stages into the pipeline.

### Project Schema

This is a combination of applications and their pipeline id's. To build this
dynamically in jsonnet we need to import all application jsonnet files for the
application and index names & pipeline ids.

## Validating Changes

It's pretty difficult to follow the single pipeline [deploy.jsonnet](./deploy.jsonnet)
without understanding Spinnaker concepts and the output json.

There is no published schema for applications or pipelines so everything is
reverse engineered based off creating pipelines with the UI (Deck microservice).

Adding jsonnet `assert ...`, and `error ...` conditions to each function is
onerous and brittle. See the `kube-libsonnet` project for good usage of these
features.

There are three strategies for validating json:

### Local file diff

Render jsonnet to json:

```
jsonnet example.jsonnet > example.json
```

Change file:

```
vim example.jsonnet
```

Render jsonnet to a different json file:

```
jsonnet example.jsonnet > example2.json
```

Diff files:

```
diff example.json example2.json
```

### API Loop

Render jsonnet to json:

```
jsonnet example.jsonnet > example.json
```

Submit to Spinnaker API:

```
spin application save --application-name example --file example.json
```

Retrieve from Spinnaker API:

```
spin pipeline get --application example --name deploy --quiet > example_got.json
```

Compare output

```
diff example.json example_got.json
```

### Deck UI

1. Render jsonnet to json.
1. Copy json into a new or existing pipeline in Deck.
1. Check if Deck displayes the pipeline structure as intended.
1. Check if Deck changes anything such as adding default values or formatting.
   After saving the pipeline you can compare the Deck json to your rendered
   json.
1. Check if the pipeline executes.
