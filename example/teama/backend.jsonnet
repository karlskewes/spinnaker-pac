// Build app configuration using object composition (extend other imported objects)
local ss = (import './project-defaults.libsonnet') + {

  _config+:: {
    description: 'Backend',
    name: 'backend',
    artifacts: {
      'backend.yaml': {
        type: 'gitlab',
        stageOrder: 1,
        stageType: 'deployManifest',
        trigger: 'gitlab',
      },
    },
  },
};

// Spinnaker spin-libsonnet application and pipeline generation

// Debug // { config: ss._config } +
{ ['application-' + ss._config.name]: ss.applications } +
{ ['pipeline-' + ss._config.name + '-' + name]: ss.pipelines[name] for name in std.objectFields(ss.pipelines) }
