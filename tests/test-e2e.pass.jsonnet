// Full example collapsed into a single file

// Typical on disk structure
/*
$ tree ../
../
├── config-defaults.jsonnet
├── deploy.jsonnet
├── infra
│   ├── project-defaults.jsonnet
│   ├── myapp1.jsonnet
│   ├── myapp2.jsonnet
├── product
│   ├── project-defaults.jsonnet
│   ├── product-app1.jsonnet
│   ├── product-app2.jsonnet
├── Makefile
├── README.md
├── spin.libsonnet
├── tests
...

*/

// ****************************************************
// ************ Example Company Defaults  *************
// ****************************************************

// Shared configuration
// Import this configuration when defining pipelines, etc.

local spin = (import '../vendor/github.com/karlskewes/spin-libsonnet/spin.libsonnet');

local defaults = {
  _config+:: {

    // Application defaults

    description: 'example default description',
    email: 'sre@example.com',
    name: 'default app',

    // Application selectors -- all must match account labels
    labels: {
      // stageBlock: null, // most apps go everywhere
      // leaky abstraction - Spinnaker 'cloudProvider' dictates available pipeline stages, eg: Deploy (EC2) or DeployManifest (K8S)
      // aws is not just ec2, but could be CodeBuild and other things associated with role (product-edit/ec2-admin)
      cloudProvider: 'kubernetes',  // aws || kubernetes
      team: null,  // least privilege principle, require decision in project/app
    },

    // Fiat authz
    serviceAccount: 'spinnaker-service-account@example.com',

    // Default application permissions
    // Note account permissions still determine ability to 'deploy'
    permissions: {
      EXECUTE: [
        'product team',
        'site reliability engineering',
      ],
      READ: [
        'product team',
        'site reliability engineering',
      ],
      WRITE: [
        // SRE only to ensure pipeline changes are done in code or acknowledged
        // Purpose is to prevent someone using freeform text field in Deploy Manifest stage
        'site reliability engineering',
      ],
    },

    // Stage defaults
    stageBlockOrdering: ['staging', 'production'],

    // Add manualJudgement wait stage to all pipelines
    customStages: {
      promoteMJ: {
        labels: { stageBlock: 'staging' },
        stageJson: spin.manualJudgment() {
          instructions: 'Promote to Production',
          notifications: [{
            address: $._config.notifications.slackChannel,
            level: 'stage',
            type: 'slack',
            when: ['manualJudgment'],
          }],
          sendNotifications: true,
          stageTimeoutMs: 86400000,
        },
        stageOrder: 99,
      },
    },

    // Artifacts
    // Docker
    docker: {
      artifactAccount: 'example-docker-acc',
      organization: 'myorg',
      registry: 'index.docker.io',
      triggerTag: '^git-.*$',
    },

    // Gitlab
    gitlab: {
      artifactAccount: 'example-gitlab-acc',
      branch: 'master',
      parentNamespaces: 'myorg',  // Escaped grandparent entities of project, eg: gitlab.com/"grandparent"/"parent"/"project"
      namespace: 'myparent',  // Spinnaker repoProject
      name: 'myproject',  // Spinnaker slug
      baseUrl: 'https://gitlab.com/api/v4/projects/' +
               $._config.gitlab.parentNamespaces + '%2F' +
               $._config.gitlab.namespace + '%2F' +
               $._config.gitlab.name +
               '/repository/files/',
    },

    // S3
    s3: {
      artifactAccount: 'example-s3-acc',
      bucket: 'example-bucket',
    },

    // Notifications

    // Build body of notification, actual notification stages will set heading
    // 1. Naively walk artifacts and based on type add a text string (will be duplicates)
    // 2. Sort unique to remove duplicates
    // 3. Join strings with newline << Requires multiple gitlabCommitBaseURL's as different repos
    // 4. Use result in Slack notification
    local notificationBody =
      std.join(
        '\n',
        std.uniq([
          if $._config.artifacts[a].trigger == 'docker' then
            'Gitlab commit: <%s' % $._config.gitlabCommitBaseURL +
            "${ trigger['artifacts'].?[type == 'docker/image'].![reference][0].replaceAll('.*:git-','') }" + '|' +
            "${ trigger['artifacts'].?[type == 'docker/image'].![reference][0].replaceAll('.*:git-','') }" + '>'
          else if $._config.artifacts[a].trigger == 'gitlab' then
            'Gitlab commit: <%s' % $._config.gitlabCommitBaseURL +
            // awful SPeL - sometimes a gitlab only pipeline (infra) may be run rather than a previous pipeline re-run.
            // previous pipeline has trigger information (commit) and manual run pipeline does not => string length issue as "master" < 8 chars.
            // ternary compare version to 'master' (safe in any case) and if not then pull version
            // note it's `commits/master` or `commit/hash` different parent dirs
            "${ trigger['artifacts'].?[type == 'gitlab/file'][0]['version'] == 'master' ? 'commits/master' : 'commit/' + trigger['artifacts'].?[type == 'gitlab/file'][0]['version'].substring(0,8) }" + '|' +
            "${ trigger['artifacts'].?[type == 'gitlab/file'][0]['version'] == 'master' ? 'commits/master' : 'commit/' + trigger['artifacts'].?[type == 'gitlab/file'][0]['version'].substring(0,8) }" + '>'
          else if $._config.artifacts[a].trigger == 's3' then
            'Gitlab commit: <%s' % $._config.gitlabCommitBaseURL +
            "${ trigger['artifacts'].?[type == 's3/object'][0]['version'] }" + '|' +
            "${ trigger['artifacts'].?[type == 's3/object'][0]['version'] }" + '>'
          else ''
          for a in std.objectFields($._config.artifacts)
          if std.objectHas($._config.artifacts[a], 'trigger')
        ])
      ),
    gitlabCommitBaseURL: 'https://gitlab.com/%s/-/' % [$._config.gitlabOrgProject],
    gitlabOrgProject: 'myorg/myproject',
    notifications: {
      slackChannel: 'deploys',
      pipeline: [
        {
          type: 'slack',
          address: $._config.notifications.slackChannel,
          when: ['pipeline.starting', 'pipeline.failed', 'pipeline.complete'],
          message: {
            'pipeline.complete': {
              text: notificationBody,
            },
            'pipeline.failed': {
              text: notificationBody,
            },
            'pipeline.starting': {
              text: notificationBody,
            },
          },

        },
      ],
      stage: {
        type: 'slack',
        address: $._config.notifications.slackChannel,
      },
    },

    // Accounts
    // Looped in artifact and deploys, with selector labels (stageBlock, team, etc) for deciding if use that account
    // account naming: <env>-<region>-<platform>-<role>
    // kubernetes 'path' is path from root of git repository
    // `regions` is a first class key in EC2 but useful for matching in kubernetes. TODO: move to label
    accounts: [
      // Cluster admin accounts
      { name: 'prd-global-ec2-admin', regions: ['ap-southeast-2', 'us-east-1'], keyPair: 'example-prd-global-spinnaker', labels: { stageBlock: 'production', cloudProvider: 'aws', cloud: 'aws', team: 'sre', infra: true } },
      { name: 'prd-ap-southeast-2-cluster-admin', path: 'prd/ap-southeast-2', labels: { stageBlock: 'production', cloudProvider: 'kubernetes', cloud: 'aws', team: 'sre', infra: true, region: 'ap-southeast-2' } },
      { name: 'prd-us-east-1-cluster-admin', path: 'prd/us-east-1', labels: { stageBlock: 'production', cloudProvider: 'kubernetes', cloud: 'aws', team: 'sre', infra: true, region: 'us-east-1' } },
      { name: 'stg-us-east-1-cluster-admin', path: 'stg/us-east-1', labels: { stageBlock: 'staging', cloudProvider: 'kubernetes', cloud: 'aws', team: 'sre', infra: true, region: 'us-east-1' } },
      { name: 'stg-global-ec2-admin', regions: ['us-east-1'], keyPair: 'example-stg-global-spinnaker', labels: { stageBlock: 'staging', cloudProvider: 'aws', cloud: 'aws', team: 'sre', infra: true } },
      // product edit accounts
      { name: 'prd-global-ec2-product-edit', regions: ['ap-southeast-2', 'us-east-1'], keyPair: 'example-prd-global-spinnaker', labels: { stageBlock: 'production', cloudProvider: 'aws', cloud: 'aws', team: 'product', product: true } },
      { name: 'prd-ap-southeast-2-product-edit', path: 'prd/ap-southeast-2', labels: { stageBlock: 'production', cloudProvider: 'kubernetes', cloud: 'aws', team: 'product', product: true, region: 'ap-southeast-2' } },
      { name: 'prd-us-east-1-product-edit', path: 'prd/us-east-1', labels: { stageBlock: 'production', cloudProvider: 'kubernetes', cloud: 'aws', team: 'product', product: true, region: 'us-east-1' } },
      { name: 'stg-us-east-1-product-edit', path: 'stg/us-east-1', labels: { stageBlock: 'staging', cloudProvider: 'kubernetes', cloud: 'aws', team: 'product', product: true, region: 'us-east-1' } },
      { name: 'stg-global-ec2-product-edit', regions: ['us-east-1'], keyPair: 'example-stg-global-spinnaker', labels: { stageBlock: 'staging', cloudProvider: 'aws', cloud: 'aws', team: 'product', product: true } },
    ],
  },


  // Code generators

  applications:: spin.application($._config.name, $._config.email) {
    cloudProviders: $._config.labels.cloudProvider,
    description: $._config.description,
    permissions: $._config.permissions,
  },

} + (import '../deploy.jsonnet');

// ****************************************************
// ************ Example Project Defaults  *************
// ****************************************************

// Normally this would be in a separate directory as `project-defaults.jsonnet`
// or similar and import config-defaults.jsonnet.

local project = defaults {
  _config+:: {
    description: 'Infra tools',
    email: 'sre@example.com',
    gitlabOrgProject: 'myorg/myproject',
    labels+: {
      team: 'sre',
      infra: true,
    },
    notifications+: {
      slackChannel: 'sre-deploys',
    },
  },
};


// ****************************************************
// *************** Example Application ****************
// ****************************************************

// Normally this would be in a separate directory with `project-defaults.jsonnet`
// and import project-defaults.jsonnet

local o = project
          {
  _config+:: {
    description: 'myapp',
    email: 'me@example.com',
    artifacts: {
      'myorg/myapp': { type: 'docker', trigger: 'docker' },
      'infra/myapp-setup.yaml': {
        type: 'gitlab',
        stageOrder: 1,
        stageType: 'runJobManifest',
      },
      'infra/myapp.yaml': {
        type: 'gitlab',
        stageOrder: 2,
        stageType: 'deployManifest',
      },
      'infra/myapp-integration-tests-job.yaml': {
        labels: { stageBlock: 'staging' },
        type: 'gitlab',
        stageOrder: 3,
        stageType: 'runJobManifest',
      },
    },
    name: 'myapp',
  },
};

// Spinnaker application and pipeline output generation

// Debug // { config: o._config } +
{ ['application-' + o._config.name]: o.applications } +
{ ['pipeline-' + o._config.name + '-' + name]: o.pipelines[name] for name in std.objectFields(o.pipelines) }
