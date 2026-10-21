// Imported by queries, variables and alerts — never import those back.
local labelNameChars = std.set(std.stringChars('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_'));

local isLabelName(attribute) =
  std.isString(attribute)
  && !std.isEmpty(attribute)
  && !std.member(std.stringChars('0123456789'), attribute[0])
  && std.all([std.member(labelNameChars, char) for char in std.stringChars(attribute)]);

local resolveGroupingAttributes(config) =
  local groupingAttributes = std.get(std.get(config, 'custom', {}), 'groupingAttributes', []);
  local invalidAttributes = [attribute for attribute in groupingAttributes if !isLabelName(attribute)];
  assert invalidAttributes == [] : 'custom.groupingAttributes must be label names, got %s; OTel attribute names need their Prometheus form (deployment.environment -> deployment_environment)' % [invalidAttributes];
  groupingAttributes;

{
  withGrouping(by, config)::
    local groupingAttributes = resolveGroupingAttributes(config);
    if groupingAttributes == [] || by == null then by
    else by + [attribute for attribute in std.set(groupingAttributes) if !std.member(by, attribute)],
}
