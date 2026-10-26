// Imported by alerts; never import those back.
local activePods = import './active_pods.libsonnet';
local grouping = import './grouping.libsonnet';
local selectors = import './selectors.libsonnet';
local tsqtsq = import 'github.com/grafana/tsqtsq/jsonnet/promql.libsonnet';

local promql = tsqtsq.promql;

local quotaBy = ['k8s_cluster_name', 'k8s_namespace_name', 'k8s_resourcequota_name', 'resource'];
local podFitBy = ['k8s_cluster_name', 'k8s_namespace_name'];
local podMaxBy = podFitBy + ['k8s_pod_name'];
local containerMaxBy = podMaxBy + ['k8s_container_name'];

local podFitResources = {
  pods: { pattern: 'pods' },
  'requests.cpu': { pattern: '(requests[.])?cpu', requestMetric: 'k8s_container_cpu_request', quotaDivisor: 1000 },
  'requests.memory': { pattern: '(requests[.])?memory', requestMetric: 'k8s_container_memory_request_bytes' },
  'limits.cpu': { pattern: 'limits[.]cpu', requestMetric: 'k8s_container_cpu_limit', quotaDivisor: 1000 },
  'limits.memory': { pattern: 'limits[.]memory', requestMetric: 'k8s_container_memory_limit_bytes' },
};

local countResourcesBelongTo = 'min';

local appliesTo(aggregation, resource) =
  std.objectHas(podFitResources[resource], 'requestMetric') || aggregation == countResourcesBelongTo;

local resolvePodFitResources(aggregation, config) =
  local requested = std.get(config, 'resourceQuotaPodFitResources', []);
  local known = std.objectFields(podFitResources);
  local unknown = [resource for resource in requested if !std.member(known, resource)];
  assert unknown == [] : 'resourceQuotaPodFitResources has unknown resource(s) %s, expected a subset of %s' % [unknown, known];
  [resource for resource in requested if appliesTo(aggregation, resource)];

local quotaHeadroom(spec, config) =
  local by = grouping.maybeWithGrouping(quotaBy, config);
  local resourceMatcher = [{ label: 'resource', operator: tsqtsq.MatchingOperator.regexMatch, value: spec.pattern }];
  local quotaMax(metric) = promql.max({ by: by, expr: selectors.selector(metric, {}, resourceMatcher, config=config) });
  local headroom = promql.sub({
    left: '(%s)' % promql.gt({ left: quotaMax('k8s_resource_quota_hard_limit'), right: '0' }),
    right: quotaMax('k8s_resource_quota_used'),
  });
  if std.objectHas(spec, 'quotaDivisor')
  then promql.div({ left: '(%s)' % headroom, right: '%d' % spec.quotaDivisor })
  else headroom;

local podRequestExtreme(aggregation, spec, config) =
  promql[aggregation]({
    by: grouping.maybeWithGrouping(podFitBy, config),
    expr: promql.sum({
      by: grouping.maybeWithGrouping(podMaxBy, config),
      expr: promql.max({
        by: grouping.maybeWithGrouping(containerMaxBy, config),
        expr: activePods.activeOnly(selectors.withCustomAttributes(spec.requestMetric, config), {}, config),
      }),
    }),
  });

local podFitBranch(aggregation, resource, config) =
  local spec = podFitResources[resource];
  local headroom = promql.gte({ left: '(%s)' % quotaHeadroom(spec, config), right: '0' });
  if std.objectHas(spec, 'requestMetric')
  then promql.lt({
    left: '(%s)' % headroom,
    right: podRequestExtreme(aggregation, spec, config),
    on: grouping.maybeWithGrouping(podFitBy, config),
    groupLeft: [],
  })
  else promql.lt({ left: '(%s)' % headroom, right: '1' });

{
  quotaBy:: quotaBy,

  podFitResources:: resolvePodFitResources,

  podFitExpr(aggregation, config)::
    std.join(' or ', [
      '(%s)' % podFitBranch(aggregation, resource, config)
      for resource in resolvePodFitResources(aggregation, config)
    ]),
}
