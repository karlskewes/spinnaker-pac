// Build app configuration using object composition (extend other imported objects)
local spin = import '../../vendor/github.com/karlskewes/spin-libsonnet/spin.libsonnet';
local ss = (import './project-defaults.libsonnet') + {

  _config+:: {
    description: 'Frontend',
    name: 'frontend',
    artifacts: {
      'exampleco/frontend': { type: 'docker', trigger: 'docker' },
      'frontend.yaml': {
        type: 'gitlab',
        stageOrder: 1,
        stageType: 'deployManifest',
        trigger: 'gitlab',
      },
    },
    customStages+: {
      triggerIntegrationTests: {
        labels: { stageBlock: 'staging' },
        stageJson: spin.wait(),
        stageOrder: 2,
      },
    },
  },
};

// Spinnaker spin-libsonnet application and pipeline generation

// Debug // { config: ss._config } +
{ ['application-' + ss._config.name]: ss.applications } +
{ ['pipeline-' + ss._config.name + '-' + name]: ss.pipelines[name] for name in std.objectFields(ss.pipelines) }
