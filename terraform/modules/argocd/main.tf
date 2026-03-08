resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [
    yamlencode({
      server = {
        service = {
          type = var.service_type
        }
        extraArgs = var.insecure ? ["--insecure"] : []
      }
      configs = {
        params = {
          "server.insecure" = var.insecure
        }
      }
    })
  ]

  wait    = true
  timeout = 600

  depends_on = [kubernetes_namespace.argocd]
}
