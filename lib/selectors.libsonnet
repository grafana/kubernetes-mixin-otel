// Imported by queries, variables and alerts — never import those back.
local tsqtsq = import 'github.com/grafana/tsqtsq/jsonnet/promql.libsonnet';

local resolveCustomAttributes(config) = std.get(std.get(config, 'custom', {}), 'attributes', []);

local selector(metric, values, attributes=[], config) =
  local customAttributes = resolveCustomAttributes(config);
  local validOperators = std.objectValues(tsqtsq.MatchingOperator);
  local invalidOperators = std.set([attribute.operator for attribute in customAttributes if !std.member(validOperators, attribute.operator)]);
  assert invalidOperators == [] : 'custom.attributes has invalid operator(s) %s on %s, expected one of %s' % [invalidOperators, metric, validOperators];
  local equalityLabels = [attribute.label for attribute in customAttributes if attribute.operator == tsqtsq.MatchingOperator.equal];
  local duplicateLabels = [label for label in std.set(equalityLabels) if std.count(equalityLabels, label) > 1];
  assert duplicateLabels == [] : 'custom.attributes has multiple %s matchers for label(s) %s on %s' % [tsqtsq.MatchingOperator.equal, duplicateLabels, metric];
  local variableLabels = std.objectFields(values);
  local attributeLabels = [attribute.label for attribute in attributes];
  local variableCollisions = [attribute.label for attribute in customAttributes if std.member(variableLabels, attribute.label)];
  assert variableCollisions == [] : 'custom.attributes label(s) %s are already matched by a dashboard variable on %s; the variable wins and the custom matcher would be discarded' % [variableCollisions, metric];
  local attributeCollisions = [attribute.label for attribute in customAttributes if std.member(attributeLabels, attribute.label)];
  assert attributeCollisions == [] : 'custom.attributes label(s) %s are already matched by a query attribute on %s' % [attributeCollisions, metric];
  tsqtsq.Expression({
    metric: metric,
    values: values,
    defaultOperator: tsqtsq.MatchingOperator.regexMatch,
    defaultSelectors: attributes + customAttributes,
  }).toString();

{
  selector:: selector,

  withCustomAttributes(metric, config)::
    if resolveCustomAttributes(config) == [] then metric else selector(metric, {}, config=config),
}
