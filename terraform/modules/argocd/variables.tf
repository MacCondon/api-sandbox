variable "argocd_version" {
  description = "Version of the ArgoCD Helm chart"
  type        = string
  default     = "5.51.6"
}

variable "service_type" {
  description = "Service type for ArgoCD server"
  type        = string
  default     = "LoadBalancer"
}

variable "insecure" {
  description = "Run ArgoCD server in insecure mode (no TLS)"
  type        = bool
  default     = true
}
