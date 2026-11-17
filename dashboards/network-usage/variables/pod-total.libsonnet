// variables path must match the path in the kubernetes-mixin template
local podVariables = import '../../resources/variables/pod.libsonnet';

{
  podTotal(config):: podVariables.pod(config),
}
