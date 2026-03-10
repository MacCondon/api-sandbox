# CloudWatch Log Group for container logs
resource "aws_cloudwatch_log_group" "containers" {
  name              = "/aws/eks/${var.cluster_name}/containers"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# IAM Role for Fluent Bit using IRSA (IAM Roles for Service Accounts)
resource "aws_iam_role" "fluent_bit" {
  name = "${var.cluster_name}-fluent-bit"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:aws-observability:fluent-bit"
          "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "fluent_bit" {
  name = "cloudwatch-logs"
  role = aws_iam_role.fluent_bit.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          aws_cloudwatch_log_group.containers.arn,
          "${aws_cloudwatch_log_group.containers.arn}:*"
        ]
      }
    ]
  })
}

# Kubernetes namespace for observability components
resource "kubernetes_namespace" "aws_observability" {
  metadata {
    name = "aws-observability"

    labels = {
      name = "aws-observability"
    }
  }
}

# Service account for Fluent Bit with IRSA annotation
resource "kubernetes_service_account" "fluent_bit" {
  metadata {
    name      = "fluent-bit"
    namespace = kubernetes_namespace.aws_observability.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.fluent_bit.arn
    }

    labels = {
      app = "fluent-bit"
    }
  }
}

# Fluent Bit Helm release
resource "helm_release" "fluent_bit" {
  name       = "fluent-bit"
  repository = "https://fluent.github.io/helm-charts"
  chart      = "fluent-bit"
  version    = "0.43.0"
  namespace  = kubernetes_namespace.aws_observability.metadata[0].name

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.fluent_bit.metadata[0].name
  }

  values = [
    yamlencode({
      config = {
        inputs = <<-EOF
          [INPUT]
              Name              tail
              Tag               kube.*
              Path              /var/log/containers/*.log
              Parser            cri
              DB                /var/log/flb_kube.db
              Mem_Buf_Limit     5MB
              Skip_Long_Lines   On
              Refresh_Interval  10
        EOF

        filters = <<-EOF
          [FILTER]
              Name                kubernetes
              Match               kube.*
              Kube_URL            https://kubernetes.default.svc:443
              Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
              Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
              Kube_Tag_Prefix     kube.var.log.containers.
              Merge_Log           On
              Keep_Log            Off
              K8S-Logging.Parser  On
              K8S-Logging.Exclude On
        EOF

        outputs = <<-EOF
          [OUTPUT]
              Name                cloudwatch_logs
              Match               kube.*
              region              ${var.aws_region}
              log_group_name      ${aws_cloudwatch_log_group.containers.name}
              log_stream_prefix   from-fluent-bit-
              auto_create_group   false
        EOF
      }
    })
  ]

  depends_on = [
    kubernetes_service_account.fluent_bit,
    aws_iam_role_policy.fluent_bit
  ]
}
