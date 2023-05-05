// Shared configuration
// Import this configuration when defining pipelines, etc.

local spin = (import '../vendor/github.com/karlskewes/spin-libsonnet/spin.libsonnet');

{
  _config+:: {

    // Application defaults

    description: 'Example co default description',
    email: 'platform@example.com',
    name: 'default app',

    // Application selectors -- all must match account labels
    labels: {
      // stageBlock: null, // most apps go everywhere
      // leaky abstraction - Spinnaker 'cloudProvider' dictates available
      // pipeline stages, eg: Deploy (EC2) or DeployManifest (K8S)
      // aws is not just ec2, but could be CodeBuild and other things
      // associated with role (teama-edit/ec2-admin)
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
        'platform team',
      ],
      READ: [
        'product team',
        'platform team',
      ],
      WRITE: [
        // Platform team only to ensure pipeline changes are done in code or acknowledged
        // Purpose is to prevent someone using freeform text field in Deploy Manifest stage
        'platform team',
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

    custom: {
      triggerTag: '^git-.*',
    },

    // Docker
    docker: {
      artifactAccount: 'dockerhub-example',
      organization: 'example',
      registry: 'index.docker.io',
      triggerTag: '^git-.*$',  // expect container images to be tagged git-<SHA>
    },

    // Gitlab
    // Variables named based off push event keys: https://docs.gitlab.com/ee/user/project/integrations/webhooks.html#push-events
    gitlab: {
      artifactAccount: 'spinnaker-gitlab-pat',
      branch: 'main',
      parentNamespaces: 'example',  // Escaped grandparent entities of project, eg: gitlab.com/"grandparent"/"parent"/"project"
      namespace: 'platform',  // Spinnaker repoProject
      name: 'monorepo',  // Spinnaker slug
      baseUrl: 'https://gitlab.com/api/v4/projects/' +
               $._config.gitlab.parentNamespaces + '%2F' +
               $._config.gitlab.namespace + '%2F' +
               $._config.gitlab.name +
               '/repository/files/',
    },

    // S3
    s3: {
      artifactAccount: 'spinnaker-clouddriver',
      bucket: 'example-us-east-1-spinnaker-artifacts',
    },

    // Notifications

    gitlabCommitBaseURL: 'https://gitlab.com/%s/-/' % [$._config.gitlabOrgProject],
    gitlabOrgProject: 'example/platform/monorepo',
    // Build body of notification, actual notification stages will set heading
    // 1. Naively walk artifacts and based on type add a text string (will be duplicates)
    // 2. Sort unique to remove duplicates
    // 3. Join strings with newline << Requires multiple gitlabCommitBaseURL's as different repos
    // 4. Use result in Slack notification
    local notificationBodyBuilder =
      std.join(
        '\n',
        std.uniq([
          if $._config.artifacts[a].trigger == 'docker' then
            local sha = "${ trigger['artifacts'].?[type == 'docker/image'].![reference][0].replaceAll('.*:git-([a-f0-9]{4,40}).*','$1') }";
            'Gitlab commit: <%s' % $._config.gitlabCommitBaseURL + 'commit/%s|%s>' % [sha, sha]
          else if $._config.artifacts[a].trigger == 'gitlab' then
            // awful SPeL - sometimes a gitlab only pipeline (monorepo) may be run rather than a previous pipeline re-run.
            // previous pipeline has trigger information (commit) and manual run pipeline does not => string length issue as "master" < 8 chars.
            // ternary compare version to 'master' (safe in any case) and if not then pull version
            // note it's `commits/master` or `commit/hash` different parent dirs
            local shaURL = "${ trigger['artifacts'].?[type == 'gitlab/file'][0]['version'] == 'master' ? 'commits/master' : 'commit/' + trigger['artifacts'].?[type == 'gitlab/file'][0]['version'].substring(0,8) }";
            local sha = "${ trigger['artifacts'].?[type == 'gitlab/file'][0]['version'] == 'master' ? 'master' : trigger['artifacts'].?[type == 'gitlab/file'][0]['version'].substring(0,8) }";
            'Gitlab commit: <%s' % $._config.gitlabCommitBaseURL + shaURL + '|' + sha + '>'
          else if ($._config.artifacts[a].trigger == 'webhook') && ($._config.artifacts[a].type == 'custom') then
            local sha = "${ trigger['artifacts'].?[name == '%s'][0].version.replaceAll('git-([a-f0-9]{4,40}).*','$1') }" % a;
            'Gitlab commit - %s: <%s' % [a, $._config.gitlabCommitBaseURL] + 'commit/%s|%s>' % [sha, sha]
          else if ($._config.artifacts[a].trigger == 'webhook') && ($._config.artifacts[a].type == 'embedded') then
            local sha = "${ trigger['artifacts'].?[name == '%s'][0].metadata.version.replaceAll('git-([a-f0-9]{4,40}).*','$1') }" % a;
            'Gitlab commit - %s: <%s' % [a, $._config.gitlabCommitBaseURL] + 'commit/%s|%s>' % [sha, sha]
          else if ($._config.artifacts[a].trigger == 'webhook') && ($._config.artifacts[a].type == 's3') then
            local sha = "${ trigger['artifacts'].?[type == 's3/object'][0]['version'] }";
            'Gitlab commit: <%s' % $._config.gitlabCommitBaseURL + 'commit/%s|%s>' % [sha, sha]
          else ''
          for a in std.objectFields($._config.artifacts)
          if std.objectHas($._config.artifacts[a], 'trigger')
        ])
      ),
    notifications: {
      slackChannel: 'product-deploys',
      pipeline: [
        {
          type: 'slack',
          address: $._config.notifications.slackChannel,
          when: ['pipeline.starting', 'pipeline.failed', 'pipeline.complete'],
          message: {
            'pipeline.complete': {
              text: notificationBodyBuilder,
            },
            'pipeline.failed': {
              text: notificationBodyBuilder,
            },
            'pipeline.starting': {
              text: notificationBodyBuilder,
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
    // Looped in artifact and deploys, with selector labels (env, projects) for deciding if use that account
    // account naming: <env>-<region>-<platform>-<role>
    accounts: [
      // Cluster admin accounts
      { name: 'prd-global-ec2-admin', regions: ['ap-southeast-2', 'us-east-2'], keyPair: 'example-prd-global-spinnaker', labels: { stageBlock: 'production', cloudProvider: 'aws', cloud: 'aws', team: 'platform', monorepo: true } },
      { name: 'prd-ap-southeast-2-eks-01-cluster-admin', path: 'kubernetes/prd/ap-southeast-2-eks-01', labels: { stageBlock: 'production', cloudProvider: 'kubernetes', cloud: 'aws', team: 'platform', monorepo: true, teama: true, 'twg-elastic': true, region: 'ap-southeast-2' } },
      { name: 'prd-us-east-2-eks-01-cluster-admin', path: 'kubernetes/prd/us-east-2-eks-01', labels: { stageBlock: 'production', cloudProvider: 'kubernetes', cloud: 'aws', team: 'platform', monorepo: true, teama: true, region: 'us-east-2' } },
      { name: 'stg-ap-southeast-2-eks-01-cluster-admin', path: 'kubernetes/stg/ap-southeast-2-eks-01', labels: { stageBlock: 'staging', cloudProvider: 'kubernetes', cloud: 'aws', team: 'platform', monorepo: true, teama: true, region: 'ap-southeast-2' } },
      { name: 'stg-global-ec2-admin', regions: ['ap-southeast-2'], keyPair: 'example-stg-global-spinnaker', labels: { stageBlock: 'staging', cloudProvider: 'aws', cloud: 'aws', team: 'platform', monorepo: true } },
      // teama edit accounts
      { name: 'prd-global-ec2-teama-edit', regions: ['ap-southeast-2', 'us-east-2'], keyPair: 'example-prd-global-spinnaker', labels: { stageBlock: 'production', cloudProvider: 'aws', cloud: 'aws', team: 'product', teama: true } },
      { name: 'prd-ap-southeast-2-eks-01-teama-edit', path: 'kubernetes/prd/ap-southeast-2-eks-01', labels: { stageBlock: 'production', cloudProvider: 'kubernetes', cloud: 'aws', team: 'product', teama: true, region: 'ap-southeast-2' } },
      { name: 'prd-us-east-2-eks-01-teama-edit', path: 'kubernetes/prd/us-east-2-eks-01', labels: { stageBlock: 'production', cloudProvider: 'kubernetes', cloud: 'aws', team: 'product', teama: true, region: 'us-east-2' } },
      { name: 'stg-ap-southeast-2-eks-01-teama-edit', path: 'kubernetes/stg/ap-southeast-2-eks-01', labels: { stageBlock: 'staging', cloudProvider: 'kubernetes', cloud: 'aws', team: 'product', teama: true, region: 'ap-southeast-2' } },
      { name: 'stg-global-ec2-teama-edit', regions: ['ap-southeast-2'], keyPair: 'example-stg-global-spinnaker', labels: { stageBlock: 'staging', cloudProvider: 'aws', cloud: 'aws', team: 'product', teama: true } },
    ],
  },


  // Code generators

  applications:: spin.application($._config.name, $._config.email) {
    cloudProviders: $._config.labels.cloudProvider,
    description: $._config.description,
    permissions: $._config.permissions,
  },

} + (import '../deploy.jsonnet')
