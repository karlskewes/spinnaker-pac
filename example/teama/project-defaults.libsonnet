(import '../config-defaults.jsonnet') + {
  _config+:: {
    description: 'Team A',
    email: 'teama@example.com',
    gitlabOrgProject: 'example/product/teama',
    labels+: {
      team: 'teama',
      infra: true,
    },
    slackChannel: 'teama',
    notifications+: { slackChannel: 'teama-deploys' },
  },
}
