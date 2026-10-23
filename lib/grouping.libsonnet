// Imported by queries, variables and alerts — never import those back.
local prometheusLabelNameChars = std.set(std.stringChars('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_'));

local isValidPrometheusLabelName(attribute) =
  std.isString(attribute)
  && !std.isEmpty(attribute)
  && !std.member(std.stringChars('0123456789'), attribute[0])
  && std.all([std.member(prometheusLabelNameChars, char) for char in std.stringChars(attribute)]);

local resolveGroupingAttributes(config) =
  local groupingAttributes = std.get(std.get(config, 'custom', {}), 'groupingAttributes', []);
  local notStrings = [attribute for attribute in groupingAttributes if !std.isString(attribute)];
  assert notStrings == [] : 'custom.groupingAttributes must be label name strings, got %s' % [notStrings];
  local dottedAttributes = [attribute for attribute in groupingAttributes if std.member(attribute, '.')];
  assert dottedAttributes == [] : 'custom.groupingAttributes %s look like OTel attribute names; use their Prometheus form (deployment.environment.name -> deployment_environment_name)' % [dottedAttributes];
  local invalidAttributes = [attribute for attribute in groupingAttributes if !isValidPrometheusLabelName(attribute)];
  assert invalidAttributes == [] : 'custom.groupingAttributes must be valid Prometheus label names, got %s' % [invalidAttributes];
  groupingAttributes;

{
  // by == null means the caller aggregates without a by clause; grouping it would break single-value panels
  maybeWithGrouping(by, config)::
    local groupingAttributes = resolveGroupingAttributes(config);
    if groupingAttributes == [] || by == null then by
    else by + [attribute for attribute in std.set(groupingAttributes) if !std.member(by, attribute)],
}
