(import '../config-defaults.jsonnet') + {
  _config+:: {
    description: 'Platform Team',
    email: 'platform@example.com',
    gitlabOrgProject: 'example/platform/monorepo',
    labels+: {
      team: 'platform',
      platform: true,
    },
    slackChannel: 'platform',
    notifications+: { slackChannel: 'platform-deploys' },
  },
}
