// expect: aggregation must be max or min
local quota = import '../../../lib/resource_quota.libsonnet';

quota.podFitExpr('mean', { resourceQuotaPodFitResources: ['requests.cpu'] })
