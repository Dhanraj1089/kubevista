# KubeVista -- Kubernetes Monitoring with Prometheus & Grafana

KubeVista is a local Kubernetes observability lab built with
**Minikube**, **Terraform**, **Helm**, **Prometheus**, and **Grafana**.
It is intended to help monitor application pods, Kubernetes object
health, CPU and memory consumption, and container restarts.

> **Current implementation status:** The `monitoring` namespace and
> `kube-prometheus-stack` Helm release have been installed. The
> monitoring pods were observed in `Running` state. The Grafana
> dashboard is the next build step; do not assume that custom panels
> have already been created.

## 1. Architecture

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
    TF -->|"Kubernetes provider / Helm provider (when configured)"| MK
    BROWSER <-->|"localhost:3000 via kubectl port-forward"| GRAF
    BROWSER <-->|"localhost:9090 via kubectl port-forward (optional)"| PROM
```

### Component responsibilities

  -----------------------------------------------------------------------
  Component               Namespace               Responsibility
  ----------------------- ----------------------- -----------------------
  `nginx-app`             `monitoring-lab`        Example workload being
                                                  monitored

  Prometheus              `monitoring`            Scrapes and stores
                                                  time-series metrics

  Grafana                 `monitoring`            Queries Prometheus and
                                                  displays dashboards

  kube-state-metrics      `monitoring`            Exposes Kubernetes
                                                  object and pod-state
                                                  metrics

  Node Exporter           `monitoring`            Exposes node-level
                                                  metrics

  Alertmanager            `monitoring`            Handles alerts sent by
                                                  Prometheus

  Prometheus Operator     `monitoring`            Manages Prometheus
                                                  monitoring resources
  -----------------------------------------------------------------------

**Metrics flow:** Kubernetes exporters and metric endpoints expose
metrics → Prometheus collects them → Grafana queries Prometheus using
PromQL → dashboard panels visualize the results.

## 2. Prerequisites

-   Windows 11 with PowerShell
-   Minikube and `kubectl`
-   Helm 3
-   Terraform (for infrastructure managed through Terraform)
-   A running Minikube cluster with the application namespace/workload

Check the tools and cluster:

``` powershell
minikube status
kubectl get nodes
kubectl get namespaces
kubectl get pods -A
helm version
terraform version
```

## 3. Namespaces

KubeVista separates the example workload from the monitoring stack:

-   `monitoring-lab` -- application workload, including `nginx-app`
-   `monitoring` -- Prometheus, Grafana, exporters, operator and
    Alertmanager

Create the monitoring namespace if it does not exist:

``` powershell
kubectl create namespace monitoring
```

If it already exists, Kubernetes will report that it already exists;
that is fine.

## 4. Install the monitoring stack

Add and update the Prometheus Community Helm repository:

``` powershell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

Install the chart:

``` powershell
helm install kubevista prometheus-community/kube-prometheus-stack -n monitoring
```

Check the release and pods:

``` powershell
helm list -n monitoring
kubectl get pods -n monitoring
```

Wait until the pods show `Running` and their containers are ready. The
stack commonly includes Prometheus, Grafana, Alertmanager,
kube-state-metrics, Node Exporter and the Prometheus Operator.

> If the release already exists, inspect it with
> `helm status kubevista -n monitoring` rather than running
> `helm install` again.

## 5. Access Grafana

Start port forwarding in a dedicated PowerShell window:

``` powershell
kubectl port-forward svc/kubevista-grafana 3000:80 -n monitoring
```

Keep this command running while using Grafana. It is expected to occupy
the terminal. Stop it with **Ctrl+C**.

Open <http://localhost:3000>.

The chart's default administrator username is commonly `admin`. Retrieve
the actual username and password from the Kubernetes Secret rather than
assuming a default password:

``` powershell
$encodedUser = kubectl get secret kubevista-grafana -n monitoring -o jsonpath="{.data.admin-user}"
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encodedUser))

$encodedPassword = kubectl get secret kubevista-grafana -n monitoring -o jsonpath="{.data.admin-password}"
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encodedPassword))
```

**Security:** Do not commit credentials, decoded Secret values,
Terraform state, or kubeconfig files to Git. If a password has been
exposed, reset it and rotate/update the corresponding Helm-managed
configuration so that the running Grafana instance and deployment
configuration remain consistent.

## 6. Prometheus data source

The in-cluster Prometheus service address for this Helm release is:

``` text
http://kubevista-kube-prometheus-prometheus.monitoring:9090
```

This is an internal Kubernetes DNS address. It is intended for
Grafana-to-Prometheus communication inside the cluster; it will not
normally resolve from the Windows host browser.

The kube-prometheus-stack chart normally provisions a Prometheus data
source in Grafana. Check **Connections → Data sources** in Grafana. If
the data source exists, open it and use **Save & test**.

Optional: access the Prometheus UI from Windows in a separate PowerShell
window:

``` powershell
kubectl port-forward svc/kubevista-kube-prometheus-prometheus 9090:9090 -n monitoring
```

Then open <http://localhost:9090>. Stop forwarding with **Ctrl+C**.

## 7. Verify metrics in Grafana Explore

In Grafana, open **Explore**, choose the Prometheus data source, and run
these queries.

### Pods discovered by kube-state-metrics

``` promql
kube_pod_info
```

### Pods in the application namespace

``` promql
kube_pod_info{namespace="monitoring-lab"}
```

### Running pods

``` promql
sum(kube_pod_status_phase{phase="Running"} == 1)
```

### Failed pods

``` promql
sum(kube_pod_status_phase{phase="Failed"} == 1)
```

### Container restarts by pod

``` promql
sum by (namespace, pod) (
  kube_pod_container_status_restarts_total
)
```

### CPU usage by pod

``` promql
sum by (namespace, pod) (
  rate(container_cpu_usage_seconds_total{
    container!="",
    container!="POD"
  }[5m])
)
```

### Memory working set by pod

``` promql
sum by (namespace, pod) (
  container_memory_working_set_bytes{
    container!="",
    container!="POD"
  }
)
```

If a query returns no data, verify that the relevant metric exists in
Prometheus before changing the dashboard. Some container metrics depend
on the kubelet/cAdvisor scrape configuration and may need
troubleshooting.

## 8. Create the KubeVista dashboard

In Grafana:

1.  Open **Dashboards → New → New dashboard**.
2.  Select **Add visualization**.
3.  Choose the Prometheus data source.
4.  Enter a PromQL query.
5.  Select the visualization type and configure the title, unit and
    legend.
6.  Click **Apply**.
7.  Repeat for each panel.
8.  Save the dashboard as **KubeVista - Kubernetes Monitoring**.

Suggested panels:

  ----------------------------------------------------------------------------------------------------
  Panel                   Visualization           PromQL
  ----------------------- ----------------------- ----------------------------------------------------
  Total Kubernetes Pods   Stat                    `count(kube_pod_info)`

  Running Pods            Stat                    `sum(kube_pod_status_phase{phase="Running"} == 1)`

  Failed Pods             Stat                    `sum(kube_pod_status_phase{phase="Failed"} == 1)`

  CPU Usage per Pod       Time series             CPU query above

  Memory Usage per Pod    Time series             Memory query above

  Pod Restart Count       Table                   Restart query above
  ----------------------------------------------------------------------------------------------------

For CPU and memory panels, use `{{namespace}} / {{pod}}` as the legend
format where supported.

## 9. Useful operational commands

``` powershell
# Cluster and node
minikube status
kubectl get nodes

# Workload
kubectl get pods -n monitoring-lab
kubectl get deployments -n monitoring-lab

# Monitoring stack
kubectl get pods -n monitoring
kubectl get svc -n monitoring
helm status kubevista -n monitoring

# Grafana logs
kubectl logs deployment/kubevista-grafana -n monitoring -c grafana --tail=50

# Grafana port-forward
kubectl port-forward svc/kubevista-grafana 3000:80 -n monitoring

# Prometheus port-forward
kubectl port-forward svc/kubevista-kube-prometheus-prometheus 9090:9090 -n monitoring
```

## 10. Suggested repository layout

``` text
kubevista/
├── terraform/
│   ├── main.tf
│   ├── providers.tf
│   ├── variables.tf
│   └── outputs.tf
├── monitoring/
│   ├── prometheus/
│   └── grafana/
│       └── dashboards/
│           └── kubevista-dashboard.json
└── README.md
```

This is a suggested target structure. Add the dashboard JSON after
exporting the dashboard from Grafana. The Helm installation described
above was performed with the Helm CLI; it is not automatically managed
by Terraform until a Helm provider release resource is added to the
Terraform configuration.

## 11. Roadmap

-   [x] Create/retain separate application and monitoring namespaces
-   [x] Install `kube-prometheus-stack` with Helm
-   [x] Verify monitoring pods are running
-   [ ] Complete Grafana administrator login and credential rotation
-   [ ] Verify Prometheus data source connectivity
-   [ ] Verify `nginx-app` metrics in Explore
-   [ ] Create and save the KubeVista dashboard
-   [ ] Export dashboard JSON and keep it under version control
-   [ ] Manage the Helm release and dashboard provisioning through
    Terraform
-   [ ] Add alert rules for pod failures, restarts and resource
    thresholds

## 12. Notes

-   `kubectl port-forward` is a foreground process; a terminal that
    appears to be waiting is normal.
-   Use **Ctrl+C** to stop port forwarding.
-   Keep Grafana and Prometheus internal service DNS names separate from
    host browser URLs.
-   Metric availability depends on the scrape targets and exporters
    actually running and being scraped.
-   Do not expose Grafana or Prometheus publicly for this local lab
    without appropriate authentication, network restrictions and TLS.

------------------------------------------------------------------------

**Project:** KubeVista\
**Purpose:** Kubernetes observability and pod-health monitoring lab\
**Stack:** Minikube · Kubernetes · Terraform · Helm · Prometheus ·
Grafana
