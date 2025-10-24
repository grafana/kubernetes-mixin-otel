# opentelemetry-mixin

1. Run `lgtm.sh` to start the cluster
1. Forward to localhost:3001
    ```
    kubectl port-forward service/lgtm 3001:3000 4317:4317 4318:4318
    ```
1. Go to `localhost:3001/admin/provisioning` to connect the instance to the github repository