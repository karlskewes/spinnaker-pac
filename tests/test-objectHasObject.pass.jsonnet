local utils = import '../utils.libsonnet';
local objects = {

  cluster: {
    name: 'my-cluster',
    path: 'path/to/my-cluster',
    labels: { environment: 'production', cloudProvider: 'kubernetes', cloud: 'skynet', team: 'sre', infra: true },
  },

  application: {
    name: 'my-app',
    labels: { environment: 'production', cloudProvider: 'kubernetes' },
  },
};
{
  assert utils.objectHasObject(objects.cluster.labels, objects.application.labels) : 'not all key values were found',
}
