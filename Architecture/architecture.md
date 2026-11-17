# KubeVista Architecture

``` mermaid
flowchart TB
    subgraph WIN["Windows 11 workstation"]
        PS["PowerShell"]
        TF["Terraform"]
        BROWSER["Web browser"]
    end

    subgraph MK["Minikube Kubernetes cluster"]
        subgraph APP["Namespace: monitoring-lab"]
            APPDEP["nginx-app Deployment"]
            APPPOD["nginx-app Pod(s)"]
            APPDEP --> APPPOD
        end

        subgraph MON["Namespace: monitoring"]
            PROM["Prometheus"]
            GRAF["Grafana"]
            KSM["kube-state-metrics"]
            NODE["Prometheus Node Exporter"]
            ALERT["Alertmanager"]
            OP["Prometheus Operator"]
        end

        KSM -->|"Kubernetes object metrics"| PROM
        NODE -->|"Node / host metrics"| PROM
        PROM -->|"PromQL queries"| GRAF
        PROM --> ALERT
        OP -.->|"Manages monitoring resources"| PROM
        OP -.-> ALERT
    end

    PS -->|"kubectl / Helm"| MK
    TF -->|"Kubernetes / Helm providers when configured"| MK
    BROWSER <-->|"localhost:3000 via port-forward"| GRAF
    BROWSER <-->|"localhost:9090 via port-forward"| PROM
```

## Data flow

1.  Kubernetes workloads run in `monitoring-lab`.
2.  `kube-state-metrics` exposes Kubernetes object and pod-state
    metrics.
3.  Node Exporter exposes node-level metrics.
4.  Prometheus scrapes configured metric endpoints and stores
    time-series data.
5.  Grafana queries Prometheus using PromQL and visualizes the results.
6.  Alertmanager handles alerts routed from Prometheus.

## Namespaces

-   `monitoring-lab`: example application workload (`nginx-app`).
-   `monitoring`: Prometheus, Grafana, Alertmanager, kube-state-metrics,
    Node Exporter and Prometheus Operator.
