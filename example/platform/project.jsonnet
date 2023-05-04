local ss = (import '../config-defaults.jsonnet') + (import '../../projects.jsonnet') + {
  _config+:: {
    description: 'Platform Team',
    email: 'platform@example.com',
    labels: {
      team: 'platform',
      platform: true,
    },
    name: 'platform',
    applications:: {
      // find . -name '*.jsonnet' | sort | sed "s@\./\(.*\)\.jsonnet@'\1': (import './\1.jsonnet'),@g" | pbcopy
      spinnaker: (import './spinnaker.jsonnet'),
      prometheus: (import './prometheus.jsonnet'),
    },
  },
};

{ ['project-' + name]: ss.projects[name] for name in std.objectFields(ss.projects) }
