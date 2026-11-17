
# Create Kubernetes namespace

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.namespace
  }
}

# Create nginx deployment

resource "kubernetes_deployment" "nginx" {

  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.monitoring.metadata[0].name

    labels = {
      app = var.app_name
    }
  }

  spec {
    replicas = var.replica_count

    selector {
      match_labels = {
        app = var.app_name
      }
    }

    template {
      metadata {
        labels = {
          app = var.app_name
        }
      }

      spec {
        container {
          name  = "nginx"
          image = var.nginx_image

          port {
            container_port = 80
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "64Mi"
            }

            limits = {
              cpu    = "500m"
              memory = "128Mi"
            }
          }
        }
      }
    }
  }
}
