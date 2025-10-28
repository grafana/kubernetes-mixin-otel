# opentelemetry-mixin

1. Run `lgtm.sh` to start the cluster
1. Go to `localhost:3000/admin/provisioning` to connect the instance to the github repository

## Useful commands
- Delete cluster
    - `k3d cluster delete otel-mixin`
- ssh into your pod
    - `kubectl exec -it ${pod-name} -- /bin/bash`
- Port forwarding
    - `kubectl port-forward service/lgtm 3001:3000 4317:4317 4318:4318`