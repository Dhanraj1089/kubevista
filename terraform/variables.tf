
variable "namespace" {
  description = "Kubernetes namespace for our monitoring project"
  type        = string
  default     = "monitoring-lab"
}

variable "app_name" {
  description = "Name of the nginx application"
  type        = string
  default     = "nginx-app"
}

variable "replica_count" {
  description = "Number of nginx pod replicas"
  type        = number
  default     = 3
}

variable "nginx_image" {
  description = "Docker image used for nginx containers"
  type        = string
  default     = "nginx:latest"
}
