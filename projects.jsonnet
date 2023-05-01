// TODO(karlskewes)
// 1. Reogranize _config. Follow prometheus and move Project, Application, Pipeline configuration to sub object of _config
//    This prevents overwriting unexpectedly, paves way for imports?
local utils = import './utils.libsonnet';
local spin = import './vendor/github.com/karlskewes/spin-libsonnet/spin.libsonnet';

{
  _config+:: {
    name+: '',
    email+: '',
    accounts+: [],
    applications+: {},
    clusters+: [],
    pipelineConfigs+: [],
  },

  // extract application names from project
  local applications = [
    app
    for app in std.objectFields($._config.applications)
  ],

  // extract matching clusters from example-config
  local clusters = [
    {
      account: account.name,
      applications: null,
      detail: '*',
      stack: '*',
    }
    for account in $._config.accounts
    if utils.objectHasObject(account.labels, $._config.labels)
  ],

  // extract pipeline names from applications
  local pipelineConfigs = [
    {
      application: app,
      pipelineConfigId: '%s-deploy' % app,  // TODO: lookup dynamically
    }
    for app in std.objectFields($._config.applications)
    // TODO: Move pipelines to under a pipeline: key so can lookup dynamically
    // for pipeline in std.objectFields(app.pipelines)
  ],

  projects+: {
    [$._config.name]: spin.project($._config.name, $._config.email) {
      id: ('%s-project' % $._config.name),
      config: {
        applications: applications,
        clusters: clusters,
        pipelineConfigs: pipelineConfigs,
      },
    },
  },
}
