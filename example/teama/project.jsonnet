local ss = (import '../config-defaults.jsonnet') + (import '../../projects.jsonnet') + {
  _config+:: {
    description: 'Team A',
    email: 'teama@example.com',
    labels: {
      team: 'teama',
      infra: true,
    },
    name: 'teama',
    applications:: {
      // find . -name '*.jsonnet' | sort | sed "s@\./\(.*\)\.jsonnet@'\1': (import './\1.jsonnet'),@g" | pbcopy
      backend: (import './backend.jsonnet'),
      frontend: (import './frontend.jsonnet'),
    },
  },
};

{ ['project-' + name]: ss.projects[name] for name in std.objectFields(ss.projects) }
