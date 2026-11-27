// variables path must match the path in the kubernetes-mixin template
local namespaceVariables = import '../../resources/variables/namespace.libsonnet';

{
  namespaceByPod(config):: namespaceVariables.namespace(config),
}
