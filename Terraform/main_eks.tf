locals {
  eks_enabled = var.use_eks
}

module "eks" {
  source = "./modules/eks"
  count  = local.eks_enabled ? 1 : 0

  project_name       = var.project_name
  region             = var.region
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  node_instance_type = var.instance_type
  node_desired_size  = 4
  node_min_size      = 4
  node_max_size      = 4
}

# Local variables to simplify Kubernetes provider configuration
locals {
  cluster_endpoint = local.eks_enabled ? module.eks[0].cluster_endpoint : null
  cluster_ca_cert  = local.eks_enabled ? base64decode(module.eks[0].cluster_certificate_authority_data) : null
}

# Data source for authentication token
data "aws_eks_cluster_auth" "eks" {
  count = local.eks_enabled ? 1 : 0
  name  = module.eks[0].cluster_name
}

provider "kubernetes" {
  alias                  = "eks"
  host                   = local.cluster_endpoint
  cluster_ca_certificate = local.cluster_ca_cert
  token                  = local.eks_enabled ? data.aws_eks_cluster_auth.eks[0].token : null
}

resource "kubernetes_namespace" "microservices" {
  count    = local.eks_enabled ? 1 : 0
  provider = kubernetes.eks
  metadata {
    name = var.kubernete.namespace
  }

  depends_on = [module.eks[0].admin_access_policy_association_arn]
}

resource "kubernetes_storage_class" "gp3" {
  count = local.eks_enabled ? 1 : 0
  provider = kubernetes.eks

  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true

  parameters = {
    type = "gp3"
  }

  depends_on = [module.eks[0].admin_access_policy_association_arn]
}

resource "kubernetes_secret" "redis_auth" {
  count    = local.eks_enabled ? 1 : 0
  provider = kubernetes.eks
  metadata {
    name      = "redis-auth"
    namespace = var.kubernete.namespace
  }
  data = {
    redis-password = var.kubernete.redis_password
  }

  depends_on = [kubernetes_namespace.microservices]
}

resource "kubernetes_secret" "rabbitmq_auth" {
  count    = local.eks_enabled ? 1 : 0
  provider = kubernetes.eks
  metadata {
    name      = "rabbitmq-auth"
    namespace = var.kubernete.namespace
  }
  data = {
    rabbitmq-username = var.kubernete.rabbitmq_username
    rabbitmq-password = var.kubernete.rabbitmq_password
  }

  depends_on = [kubernetes_namespace.microservices]
}

resource "kubernetes_persistent_volume_claim" "redis_data" {
  count    = local.eks_enabled ? 1 : 0
  provider = kubernetes.eks
  metadata {
    name      = "redis-data"
    namespace = var.kubernete.namespace
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
    storage_class_name = kubernetes_storage_class.gp3[0].metadata[0].name
  }

  depends_on = [
    kubernetes_namespace.microservices,
    kubernetes_storage_class.gp3,
  ]
}

resource "kubernetes_persistent_volume_claim" "rabbitmq_data" {
  count    = local.eks_enabled ? 1 : 0
  provider = kubernetes.eks
  metadata {
    name      = "rabbitmq-data"
    namespace = var.kubernete.namespace
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
    storage_class_name = kubernetes_storage_class.gp3[0].metadata[0].name
  }

  depends_on = [
    kubernetes_namespace.microservices,
    kubernetes_storage_class.gp3,
  ]
}

resource "kubernetes_persistent_volume_claim" "n8n_data" {
  count    = local.eks_enabled ? 1 : 0
  provider = kubernetes.eks
  metadata {
    name      = "n8n-data"
    namespace = var.kubernete.namespace
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
    storage_class_name = kubernetes_storage_class.gp3[0].metadata[0].name
  }

  depends_on = [
    kubernetes_namespace.microservices,
    kubernetes_storage_class.gp3,
  ]
}

resource "kubernetes_deployment" "redis" {
  count    = local.eks_enabled ? 1 : 0
  provider = kubernetes.eks
  metadata {
    name      = "redis"
    namespace = var.kubernete.namespace
    labels    = { app = "redis" }
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "redis" } }
    template {
      metadata { labels = { app = "redis" } }
      spec {
        container {
          name  = "redis"
          image = "redis:alpine"
          port {
            container_port = 6379
          }
          env {
            name = "REDIS_PASSWORD"
            value_from {
              secret_key_ref {
                name = "redis-auth"
                key  = "redis-password"
              }
            }
          }
          command = ["sh", "-c", "exec redis-server --requirepass \"$REDIS_PASSWORD\""]
          liveness_probe {
            exec { command = ["sh", "-c", "redis-cli -a \"$REDIS_PASSWORD\" ping"] }
            initial_delay_seconds = 10
            period_seconds        = 10
          }
          readiness_probe {
            exec { command = ["sh", "-c", "redis-cli -a \"$REDIS_PASSWORD\" ping"] }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
          resources {
            limits   = { cpu = "200m", memory = "256Mi" }
            requests = { cpu = "100m", memory = "128Mi" }
          }
          volume_mount {
            mount_path = "/data"
            name       = "redis-data"
          }
        }
        volume {
          name = "redis-data"
          persistent_volume_claim { claim_name = "redis-data" }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.microservices,
    kubernetes_secret.redis_auth,
    kubernetes_persistent_volume_claim.redis_data,
  ]
}

resource "kubernetes_service" "redis" {
  count    = local.eks_enabled ? 1 : 0
  provider = kubernetes.eks
  metadata {
    name      = "redis"
    namespace = var.kubernete.namespace
    labels    = { app = "redis" }
  }
  spec {
    selector = { app = "redis" }
    port {
      port        = 6379
      target_port = 6379
    }
    type = "ClusterIP"
  }

  depends_on = [
    kubernetes_namespace.microservices,
    kubernetes_deployment.redis,
  ]
}

resource "kubernetes_deployment" "rabbitmq" {
  count    = local.eks_enabled ? 1 : 0
  provider = kubernetes.eks
  metadata {
    name      = "rabbit-mq"
    namespace = var.kubernete.namespace
    labels    = { app = "rabbit-mq" }
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "rabbit-mq" } }
    template {
      metadata { labels = { app = "rabbit-mq" } }
      spec {
        container {
          name  = "rabbit-mq"
          image = "rabbitmq:3-management"
          port {
            container_port = 5672
          }
          port {
            container_port = 15672
          }
          env {
            name = "RABBITMQ_DEFAULT_USER"
            value_from {
              secret_key_ref {
                name = "rabbitmq-auth"
                key  = "rabbitmq-username"
              }
            }
          }
          env {
            name = "RABBITMQ_DEFAULT_PASS"
            value_from {
              secret_key_ref {
                name = "rabbitmq-auth"
                key  = "rabbitmq-password"
              }
            }
          }
          startup_probe {
            exec { command = ["rabbitmqctl", "status"] }
            initial_delay_seconds = 20
            period_seconds        = 15
            timeout_seconds       = 10
            failure_threshold     = 10
          }
          liveness_probe {
            exec { command = ["rabbitmq-diagnostics", "-q", "ping"] }
            initial_delay_seconds = 180
            period_seconds        = 30
            timeout_seconds       = 10
            failure_threshold     = 3
          }
          readiness_probe {
            exec { command = ["rabbitmq-diagnostics", "-q", "ping"] }
            initial_delay_seconds = 60
            period_seconds        = 20
            timeout_seconds       = 10
            failure_threshold     = 6
          }
          resources {
            limits   = { cpu = "500m", memory = "512Mi" }
            requests = { cpu = "200m", memory = "256Mi" }
          }
          volume_mount {
            mount_path = "/var/lib/rabbitmq"
            name       = "rabbitmq-data"
          }
        }
        volume {
          name = "rabbitmq-data"
          persistent_volume_claim { claim_name = "rabbitmq-data" }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.microservices,
    kubernetes_secret.rabbitmq_auth,
    kubernetes_persistent_volume_claim.rabbitmq_data,
  ]
}

resource "kubernetes_service" "rabbitmq" {
  count    = local.eks_enabled ? 1 : 0
  provider = kubernetes.eks
  metadata {
    name      = "rabbit-mq"
    namespace = var.kubernete.namespace
    labels    = { app = "rabbit-mq" }
  }
  spec {
    selector = { app = "rabbit-mq" }
    port {
      name        = "amqp"
      port        = 5672
      target_port = 5672
    }
    port {
      name        = "management"
      port        = 15672
      target_port = 15672
    }
    type = "ClusterIP"
  }

  depends_on = [
    kubernetes_namespace.microservices,
    kubernetes_deployment.rabbitmq,
  ]
}

resource "kubernetes_deployment" "n8n" {
  count    = local.eks_enabled ? 1 : 0
  provider = kubernetes.eks
  metadata {
    name      = "n8n"
    namespace = var.kubernete.namespace
    labels    = { app = "n8n" }
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "n8n" } }
    template {
      metadata { labels = { app = "n8n" } }
      spec {
        container {
          name  = "n8n"
          image = "n8nio/n8n:latest"
          port {
            container_port = 5678
          }
          env {
            name  = "N8N_HOST"
            value = "0.0.0.0"
          }
          env {
            name  = "N8N_PORT"
            value = "5678"
          }
          env {
            name  = "N8N_PROTOCOL"
            value = "http"
          }
          env {
            name  = "N8N_SECURE_COOKIE"
            value = "false"
          }
          env {
            name  = "N8N_PATH"
            value = "/n8n/"
          }
          env {
            name  = "GENERIC_TIMEZONE"
            value = "Asia/Ho_Chi_Minh"
          }
          env {
            name  = "TZ"
            value = "Asia/Ho_Chi_Minh"
          }
          env {
            name  = "N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS"
            value = "true"
          }
          env {
            name  = "N8N_DIAGNOSTICS_ENABLED"
            value = "false"
          }
          env {
            name  = "N8N_VERSION_NOTIFICATIONS_ENABLED"
            value = "false"
          }
          env {
            name  = "N8N_TEMPLATES_ENABLED"
            value = "false"
          }
          env {
            name  = "N8N_METRICS"
            value = "true"
          }
          env {
            name  = "QUEUE_HEALTH_CHECK_ACTIVE"
            value = "true"
          }
          env {
            name  = "NODE_OPTIONS"
            value = "--max-old-space-size=512"
          }
          env {
            name  = "N8N_EDITOR_BASE_URL"
            value = "http://localhost:5678/n8n/"
          }
          env {
            name  = "WEBHOOK_URL"
            value = "http://localhost:5678/n8n/"
          }
          env {
            name  = "VUE_APP_URL_BASE_API"
            value = "http://localhost:5678/n8n/"
          }
          resources {
            limits   = { cpu = "800m", memory = "768Mi" }
            requests = { cpu = "300m", memory = "512Mi" }
          }
          liveness_probe {
            http_get {
              path = "/healthz"
              port = 5678
            }
            initial_delay_seconds = 20
            period_seconds        = 15
          }
          readiness_probe {
            http_get {
              path = "/healthz"
              port = 5678
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }
          volume_mount {
            mount_path = "/home/node/.n8n"
            name       = "n8n-data"
          }
        }
        volume {
          name = "n8n-data"
          persistent_volume_claim { claim_name = "n8n-data" }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.microservices,
    kubernetes_persistent_volume_claim.n8n_data,
  ]
}

resource "kubernetes_deployment" "n8n_proxy" {
  count    = local.eks_enabled ? 1 : 0
  provider = kubernetes.eks
  metadata {
    name      = "n8n-proxy"
    namespace = var.kubernete.namespace
    labels    = { app = "n8n-proxy" }
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "n8n-proxy" } }
    template {
      metadata { labels = { app = "n8n-proxy" } }
      spec {
        container {
          name  = "nginx"
          image = "nginx:1.27-alpine"
          port {
            container_port = 5678
          }
          resources {
            limits   = { cpu = "200m", memory = "128Mi" }
            requests = { cpu = "50m", memory = "64Mi" }
          }
          volume_mount {
            mount_path = "/etc/nginx/nginx.conf"
            name       = "nginx-conf"
            sub_path   = "nginx.conf"
          }
        }
        volume {
          name = "nginx-conf"
          config_map { name = "n8n-nginx-conf" }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.microservices,
    kubernetes_deployment.n8n,
    kubernetes_config_map.n8n_nginx_conf,
  ]
}

resource "kubernetes_config_map" "n8n_nginx_conf" {
  count    = local.eks_enabled ? 1 : 0
  provider = kubernetes.eks
  metadata {
    name      = "n8n-nginx-conf"
    namespace = var.kubernete.namespace
  }
  data = {
    "nginx.conf" = <<-EOF
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    resolver 127.0.0.11 valid=30s ipv6=off;

    map $http_upgrade $connection_upgrade {
        default upgrade;
        ''      close;
    }

    sendfile        on;
    keepalive_timeout  65;

    server {
        listen 5678;
        server_name _;

        location = /       { return 302 /n8n/; }
        location = /n8n    { return 301 /n8n/; }

        location /n8n/ {
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;

            proxy_set_header Host              $http_host;
            proxy_set_header X-Real-IP         $remote_addr;
            proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host  $http_host;
            proxy_set_header X-Forwarded-Port  $server_port;
            proxy_set_header X-Forwarded-Prefix /n8n;

            proxy_read_timeout 300;
            proxy_send_timeout 300;

            rewrite ^/n8n/(.*)$ /$1 break;
            proxy_pass http://n8n:5678/;
        }
    }
}
EOF
  }

  depends_on = [kubernetes_namespace.microservices]
}

resource "kubernetes_service" "n8n_proxy" {
  count    = local.eks_enabled ? 1 : 0
  provider = kubernetes.eks
  metadata {
    name      = "n8n-proxy"
    namespace = var.kubernete.namespace
    labels    = { app = "n8n-proxy" }
  }
  spec {
    selector = { app = "n8n-proxy" }
    port {
      port        = 5678
      target_port = 5678
    }
    type = "LoadBalancer"
  }

  depends_on = [
    kubernetes_namespace.microservices,
    kubernetes_deployment.n8n_proxy,
  ]
}

resource "kubernetes_deployment" "guest" {
  count    = local.eks_enabled ? 1 : 0
  provider = kubernetes.eks
  metadata {
    name      = "guest-microservice"
    namespace = var.kubernete.namespace
    labels    = { app = "guest-microservice" }
  }
  spec {
    replicas = 2
    selector { match_labels = { app = "guest-microservice" } }
    template {
      metadata { labels = { app = "guest-microservice" } }
      spec {
        container {
          name              = "guest-microservice"
          image             = "guest-microservice"
          image_pull_policy = "IfNotPresent"
          port {
            container_port = 5001
          }
          env {
            name  = "ASPNETCORE_ENVIRONMENT"
            value = "Production"
          }
          env {
            name  = "ASPNETCORE_URLS"
            value = "http://+:5001"
          }
          env {
            name  = "Database__Host"
            value = var.kubernete.guest_db.host
          }
          env {
            name  = "Database__Port"
            value = tostring(var.kubernete.guest_db.port)
          }
          env {
            name  = "Database__Name"
            value = var.kubernete.guest_db.name
          }
          env {
            name  = "Database__Username"
            value = var.kubernete.guest_db.username
          }
          env {
            name  = "Database__Password"
            value = var.kubernete.guest_db.password
          }
          env {
            name  = "Database__Provider"
            value = var.kubernete.guest_db.provider
          }
          env {
            name  = "RabbitMq__Host"
            value = "rabbit-mq"
          }
          env {
            name  = "RabbitMq__Port"
            value = "5672"
          }
          env {
            name  = "RabbitMq__Username"
            value = var.kubernete.rabbitmq_username
          }
          env {
            name  = "RabbitMq__Password"
            value = var.kubernete.rabbitmq_password
          }
          env {
            name  = "Redis__Host"
            value = "redis"
          }
          env {
            name  = "Redis__Password"
            value = var.kubernete.redis_password
          }
          env {
            name  = "Redis__Port"
            value = "6379"
          }
          env {
            name  = "Jwt__SecretKey"
            value = var.kubernete.jwt_secret
          }
          env {
            name  = "Jwt__Issuer"
            value = "UserMicroservice"
          }
          env {
            name  = "Jwt__Audience"
            value = "MicroservicesApp"
          }
          env {
            name  = "Jwt__ExpirationMinutes"
            value = "60"
          }
          env {
            name  = "AutoApply__Migrations"
            value = "true"
          }
          resources {
            limits   = { cpu = "700m", memory = "512Mi" }
            requests = { cpu = "300m", memory = "384Mi" }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.microservices,
    kubernetes_deployment.rabbitmq,
    kubernetes_deployment.redis,
  ]
}

resource "kubernetes_service" "guest" {
  count    = local.eks_enabled ? 1 : 0
  provider = kubernetes.eks
  metadata {
    name      = "guest-microservice"
    namespace = var.kubernete.namespace
    labels    = { app = "guest-microservice" }
  }
  spec {
    selector = { app = "guest-microservice" }
    port {
      port        = 5001
      target_port = 5001
    }
    type = "ClusterIP"
  }

  depends_on = [
    kubernetes_namespace.microservices,
    kubernetes_deployment.guest,
  ]
}

resource "kubernetes_deployment" "user" {
  count    = local.eks_enabled ? 1 : 0
  provider = kubernetes.eks
  metadata {
    name      = "user-microservice"
    namespace = var.kubernete.namespace
    labels    = { app = "user-microservice" }
  }
  spec {
    replicas = 2
    selector { match_labels = { app = "user-microservice" } }
    template {
      metadata { labels = { app = "user-microservice" } }
      spec {
        container {
          name              = "user-microservice"
          image             = "user-microservice"
          image_pull_policy = "IfNotPresent"
          port {
            container_port = 5002
          }
          env {
            name  = "ASPNETCORE_ENVIRONMENT"
            value = "Production"
          }
          env {
            name  = "ASPNETCORE_URLS"
            value = "http://+:5002"
          }
          env {
            name  = "Database__Host"
            value = var.kubernete.user_db.host
          }
          env {
            name  = "Database__Port"
            value = tostring(var.kubernete.user_db.port)
          }
          env {
            name  = "Database__Name"
            value = var.kubernete.user_db.name
          }
          env {
            name  = "Database__Username"
            value = var.kubernete.user_db.username
          }
          env {
            name  = "Database__Password"
            value = var.kubernete.user_db.password
          }
          env {
            name  = "Database__Provider"
            value = var.kubernete.user_db.provider
          }
          env {
            name  = "Database__SslMode"
            value = var.kubernete.user_db.ssl_mode
          }
          env {
            name  = "RabbitMq__Host"
            value = "rabbit-mq"
          }
          env {
            name  = "RabbitMq__Port"
            value = "5672"
          }
          env {
            name  = "RabbitMq__Username"
            value = var.kubernete.rabbitmq_username
          }
          env {
            name  = "RabbitMq__Password"
            value = var.kubernete.rabbitmq_password
          }
          env {
            name  = "Redis__Host"
            value = "redis"
          }
          env {
            name  = "Redis__Password"
            value = var.kubernete.redis_password
          }
          env {
            name  = "Redis__Port"
            value = "6379"
          }
          env {
            name  = "Jwt__SecretKey"
            value = var.kubernete.jwt_secret
          }
          env {
            name  = "Jwt__Issuer"
            value = "UserMicroservice"
          }
          env {
            name  = "Jwt__Audience"
            value = "MicroservicesApp"
          }
          env {
            name  = "Jwt__ExpirationMinutes"
            value = "60"
          }
          env {
            name  = "Cors__AllowedOrigins__0"
            value = "http://localhost:5173"
          }
          env {
            name  = "Cors__AllowedOrigins__1"
            value = "https://your-frontend.example.com"
          }
          env {
            name  = "Cors__AllowedOrigins__2"
            value = "http://localhost:2406"
          }
          env {
            name  = "AutoApply__Migrations"
            value = "true"
          }
          resources {
            limits   = { cpu = "700m", memory = "512Mi" }
            requests = { cpu = "300m", memory = "384Mi" }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.microservices,
    kubernetes_deployment.rabbitmq,
    kubernetes_deployment.redis,
  ]
}

resource "kubernetes_service" "user" {
  count    = local.eks_enabled ? 1 : 0
  provider = kubernetes.eks
  metadata {
    name      = "user-microservice"
    namespace = var.kubernete.namespace
    labels    = { app = "user-microservice" }
  }
  spec {
    selector = { app = "user-microservice" }
    port {
      port        = 5002
      target_port = 5002
    }
    type = "ClusterIP"
  }

  depends_on = [
    kubernetes_namespace.microservices,
    kubernetes_deployment.user,
  ]
}

resource "kubernetes_deployment" "api_gateway" {
  count    = local.eks_enabled ? 1 : 0
  provider = kubernetes.eks
  metadata {
    name      = "api-gateway"
    namespace = var.kubernete.namespace
    labels    = { app = "api-gateway" }
  }
  spec {
    replicas = 2
    selector { match_labels = { app = "api-gateway" } }
    template {
      metadata { labels = { app = "api-gateway" } }
      spec {
        container {
          name              = "api-gateway"
          image             = "api-gateway"
          image_pull_policy = "IfNotPresent"
          port {
            container_port = 8080
          }
          env {
            name  = "ENABLE_SWAGGER_UI"
            value = "true"
          }
          env {
            name  = "ASPNETCORE_ENVIRONMENT"
            value = "Production"
          }
          env {
            name  = "ASPNETCORE_URLS"
            value = "http://+:8080"
          }
          env {
            name  = "Services__User__Host"
            value = "user-microservice"
          }
          env {
            name  = "Services__User__Port"
            value = "5002"
          }
          env {
            name  = "Services__Guest__Host"
            value = "guest-microservice"
          }
          env {
            name  = "Services__Guest__Port"
            value = "5001"
          }
          env {
            name  = "Jwt__SecretKey"
            value = var.kubernete.jwt_secret
          }
          env {
            name  = "Jwt__Issuer"
            value = "UserMicroservice"
          }
          env {
            name  = "Jwt__Audience"
            value = "MicroservicesApp"
          }
          env {
            name  = "Jwt__ExpirationMinutes"
            value = "60"
          }
          resources {
            limits   = { cpu = "600m", memory = "384Mi" }
            requests = { cpu = "250m", memory = "256Mi" }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.microservices,
    kubernetes_deployment.user,
    kubernetes_deployment.guest,
  ]
}

resource "kubernetes_service" "api_gateway" {
  count    = local.eks_enabled ? 1 : 0
  provider = kubernetes.eks
  metadata {
    name      = "api-gateway"
    namespace = var.kubernete.namespace
    labels    = { app = "api-gateway" }
  }
  spec {
    selector = { app = "api-gateway" }
    port {
      port        = 8080
      target_port = 8080
    }
    type = "LoadBalancer"
  }

  depends_on = [
    kubernetes_namespace.microservices,
    kubernetes_deployment.api_gateway,
  ]
}
