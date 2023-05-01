// Deploy Pipeline
//
// Functionality:
// 1. Configuration:
//    - Manifest artifacts
//    - - deploy git manifests
//    - - job manifests
//    - - s3 manifests
//    - Docker artifacts
//    - Docker Trigger
//    - Gitlab Trigger (all artifacts combined in single payload)
//    - Webhook Trigger (all artifacts combined in single payload)
//    - Notify to slack (defaults)
// 2. Iterate through ..n stageBlocks (eg 'staging', 'production) stages based
//    on stageOrder set per artifact

// TODO:
// 1. golden files
// 2. consider more functions if increases testability
// 3. anything that helps reasoning about the models and manipulations

local utils = import './utils.libsonnet';
local spin = import './vendor/github.com/karlskewes/spin-libsonnet/spin.libsonnet';

{
  // placeholders
  _config+:: {
    name+: 'myapp',
    artifacts+: {
      // 'myorg/myapp': { type: 'docker', trigger: 'docker' },
      // 'git-.*.yaml': { type: 's3', trigger: 'webhook', stageOrder: 1, stageType: 'deployManifest' },
      // 'myapp-integration-tests.yaml': { type: 'gitlab', stageOrder: 2, stageType: 'runJobManifest' },
    },
    customStages+: {
      // mj: { stageBlock: 'staging', stageJson: spin.manualJudgment(), stageOrder: 99 },
    },
    notifications+: { pipeline+: [] },
    parameters+: {},
    stageBlockOrdering+: [
      // 'staging',
      // 'production',
    ],
  },

  pipelines+:: {
    deploy: {
      local p = self,
      // ****************************************************
      // ****** Artifacts, Stage & Trigger Generation *******
      // ****************************************************

      // sir (Spinnaker Intermediate Representation) translates from our
      // DSL/interface that internal customers use to Spinnaker objects.
      // sir creates all the artifact dependent Spinnaker objects in one big
      // array in a single pass (nested loop).
      // The resulting output is an array but it will be converted into
      // appropriate root objects with correct keys by later jsonnet
      //
      // constraints:
      // 1. Spinnaker schema defines `expectedArtifacts`
      // 2. `stages` require keys from associated `expectedArtifacts` they are acting on.
      // 3. `expectedArtifacts` have insufficent metadata to solely create stages from.
      // options
      // 1. loop artifacts & accounts once and in single pass build both expectedArtifacts and stages << current method
      // 2. add required metadata to hidden keys `<key>::` in expectedArtifact and then loop expectedArtifacts (stageOrder + stage type) ??
      // 3. do multiple loops like the old sponnet deploy.jsonnet pipeline.
      sir::
        // loop global Artifacts, eg: Docker Repositories, Custom Artifacts
        [
          {
            expectedArtifact:
              if $._config.artifacts[a].type == 'custom' then
                spin.customArtifact(a, $._config.custom.triggerTag)
              else if $._config.artifacts[a].type == 'docker' then
                spin.dockerArtifact(
                  $._config.docker.registry + '/' + a,
                  $._config.docker.artifactAccount,
                )
              else if $._config.artifacts[a].type == 'embedded' then
                spin.embeddedArtifact(a),
            triggers:
              if std.objectHas($._config.artifacts[a], 'trigger') then
                if $._config.artifacts[a].trigger == 'docker' then
                  spin.dockerTrigger(
                    a,
                    $._config.docker.triggerTag,
                    $._config.docker.organization,
                    $._config.docker.registry,
                    $._config.serviceAccount,
                    $._config.docker.artifactAccount,
                  )
                else if $._config.artifacts[a].trigger == 'webhook' then
                  spin.webhookTrigger(
                    $._config.name,
                    [self.expectedArtifact.id],
                    null,
                    $._config.serviceAccount,
                  ),
          }
          for a in std.objectFields($._config.artifacts)
          if std.member(['custom', 'docker', 'embedded'], $._config.artifacts[a].type)
        ] +

        // loop per-account Artifacts, eg: Gitlab & S3 YAML files
        [
          // each time around the loop we need to create:
          // 1. expectedArtifact that will be consumed/used in a stage
          // 2. stage itself
          // 3. own stage ref id with appropriate key for matching later
          // 4. the stage's requisiteStageRefIds which are late bound from
          //    `p.stageRefIds` which itself is built from #3 above.
          //    Yes this is a mind bender chicken-egg manuever.
          // 5. trigger if defined
          {
            // create artifact required for deploy
            expectedArtifact:
              if $._config.artifacts[a].type == 'gitlab' then
                spin.gitlabArtifact(
                  '%s/%s' % [acc.path, a],
                  $._config.gitlab.baseUrl,
                  $._config.gitlab.artifactAccount,
                )
              else if $._config.artifacts[a].type == 's3' then
                spin.s3Artifact(
                  // "appname/accountname-objectRegex",
                  '%s/%s-%s' % [
                    $._config.name,
                    acc.name,
                    a,
                  ],
                  $._config.s3.bucket,
                  $._config.s3.artifactAccount,
                )
              else {},

            // create stage and use artifact created above
            // note we will hydrate (object comprehension) the stages requisiteStageRefIds
            // later when we convert from $.sir.stage to $.stages
            // switch (if/else) on the `stageType: <something>` key/value to determine stage type
            // do all this via a temporary `local` variable else expectedArtifact is not found (evaluation order?)
            local s =
              if !std.objectHas($._config.artifacts[a], 'stageType') then {}
              else if $._config.artifacts[a].stageType == 'deployManifest' then
                spin.deployManifest($._config.name, a, self.expectedArtifact.id, acc.name)
              else if $._config.artifacts[a].stageType == 'runJobManifest' then
                spin.runJobManifest($._config.name, a, self.expectedArtifact.id, acc.name)
              else if $._config.artifacts[a].stageType == 'deploy' then
                spin.deploy($._config.artifacts[a].clusters)
              else {},
            stage: s +
                   (
                     if std.objectHas($._config.artifacts[a], 'stageJson') then $._config.artifacts[a].stageJson
                     else {}
                   )
                   +
                   {
                     // requisiteStageRefIds is an array of preceding stage refId's, (fan in/out).
                     requisiteStageRefIds:
                       utils.stageMatrixPreviousElement(
                         p.stageRefIds,
                         $._config.stageBlockOrdering,
                         acc.labels.stageBlock,
                         $._config.artifacts[a].stageOrder,
                       ),
                   },

            // add this stage id to req stage id list with stageOrder info, process:
            // 1: create refId per stage
            // 2: stageRefIds:: // parse #1 to build map
            // 3: rely on late bounding to make use of stageRefIds in requisiteStageRefIds above.
            refId+: {
              [acc.labels.stageBlock]+: {
                [std.toString($._config.artifacts[a].stageOrder)]+: [s.refId],
              },
            },

            // triggers created here will be combined by trigger type because
            // usually single 'event' (gitlab push / webhook) with all artifacts
            // in payload.
            triggers+:
              if std.objectHas($._config.artifacts[a], 'trigger') then
                if $._config.artifacts[a].trigger == 'gitlab' then
                  spin.gitlabTrigger(
                    [self.expectedArtifact.id],
                    $._config.gitlab.branch,
                    $._config.gitlab.namespace,
                    $._config.gitlab.name,
                    $._config.serviceAccount,
                  )
                else if $._config.artifacts[a].trigger == 'webhook' then
                  spin.webhookTrigger(
                    $._config.name,
                    [self.expectedArtifact.id],
                    null,
                    $._config.serviceAccount,
                  )
                else {},
          }

          // loop all the things
          for a in std.objectFields($._config.artifacts)  // loop artifacts
          for acc in $._config.accounts  // loop accounts
          if std.objectHas($._config.artifacts[a], 'stageOrder')  // not solely deployable, eg: docker
          if utils.objectHasObject(
            acc.labels,
            (  // merge any top level (project) labels (eg: { myproject: true }) with artifacts labels (if any)
              $._config.labels +
              if std.objectHas($._config.artifacts[a], 'labels') then $._config.artifacts[a].labels else {}
            )
          )
        ] +

        // loop any custom stages
        [
          {
            stage: $._config.customStages[s].stageJson {
              // requisiteStageRefIds is an array of preceding stage refId's, (fan in/out).
              requisiteStageRefIds:
                utils.stageMatrixPreviousElement(
                  p.stageRefIds,
                  $._config.stageBlockOrdering,
                  $._config.customStages[s].labels.stageBlock,
                  $._config.customStages[s].stageOrder,
                ),
            },

            refId+: {
              [$._config.customStages[s].labels.stageBlock]+: {
                [std.toString($._config.customStages[s].stageOrder)]+: [$._config.customStages[s].stageJson.refId],
              },
            },

          }
          // loop manually defined stages
          for s in std.objectFields($._config.customStages)
        ],


      // stageRefIds builds a map of stage refIds per each stageBlock/stageOrder
      // based on SIR intermediate output.
      // This can then be queried for doing stage ordering.
      // Recursively merge array of refIds into single object with fold function
      stageRefIds::
        std.foldl(function(x, y) x + y, [
          o.refId
          for o in p.sir
          if std.objectHas(o, 'refId')
        ], {}),

      // ****************************************************
      // ************** Generate Final Output ***************
      // ****************************************************

      // defaults
      application: $._config.name,
      id: self.application + '-deploy',
      assert std.length(self.id) <= 36 : 'Pipeline ID must be no longer than 36 characters',

      name: 'deploy',

      // Do not cancel queued pipelines
      keepWaitingPipelines: true,
      // No concurrent pipelines executing
      limitConcurrent: true,

      // expectedArtifacts converts SIR into final Spinnaker-compatible json
      expectedArtifacts+: [
        o.expectedArtifact
        for o in std.prune(p.sir)
        if std.objectHas(o, 'expectedArtifact')
      ],

      notifications+: [
        spin.notification(
          n.address,
          'pipeline',
          n.message,
          n.type,
          n.when,
        )
        for n in $._config.notifications.pipeline
        if std.length($._config.notifications.pipeline) > 0
      ],

      parameterConfig+: [
        spin.parameter(p) + $._config.parameters[p]
        for p in std.objectFields($._config.parameters)
      ],


      // stages converts SIR into final Spinnaker-compatible json
      stages+: [
        o.stage
        for o in p.sir
        if std.objectHas(o, 'stage')
      ],

      // triggers converts SIR into final Spinnaker-compatible json
      triggers+:
        // single artifact triggers
        [
          o.triggers
          for o in p.sir
          if std.objectHas(o, 'triggers') && (o.triggers != null)
          if std.objectHas(o.triggers, 'type') && (o.triggers.type == 'docker')
        ] +
        // multiple artifact triggers - combined into 1 per 'source' or 'type'
        std.prune([
          std.foldl(function(x, y) x + y, [
            o.triggers
            for o in p.sir
            if std.objectHas(o, 'triggers') && (o.triggers != null)
            if std.objectHas(o.triggers, 'source') && (o.triggers.source == 'gitlab')
          ], {}),
        ]) +
        std.prune([
          std.foldl(function(x, y) x + y, [
            o.triggers
            for o in p.sir
            if std.objectHas(o, 'triggers') && (o.triggers != null)
            if std.objectHas(o.triggers, 'type') && (o.triggers.type == 'webhook')
          ], {}),
        ]),

    },
  },
}
