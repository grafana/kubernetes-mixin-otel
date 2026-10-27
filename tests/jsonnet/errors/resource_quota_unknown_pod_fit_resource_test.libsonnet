// expect: has unknown resource(s)
local quota = import '../../../lib/resource_quota.libsonnet';

quota.podFitExpr('max', { resourceQuotaPodFitResources: ['requests.cpu', 'requests.gpu'] })
