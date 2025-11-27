k8s_resources = {
  storage_class = "sc1" # default EKS StorageClass; change to gp3/custom if available

  redis = {
    replicas = 1
    requests = { cpu = "50m", memory = "96Mi" }
    limits   = { cpu = "150m", memory = "192Mi" }
  }

  rabbitmq = {
    replicas = 1
    requests = { cpu = "150m", memory = "256Mi" }
    limits   = { cpu = "400m", memory = "512Mi" }
  }

  n8n = {
    replicas = 1
    requests = { cpu = "200m", memory = "320Mi" }
    limits   = { cpu = "500m", memory = "512Mi" }
  }

  n8n_proxy = {
    replicas = 1
    image    = "public.ecr.aws/nginx/nginx:1.27-alpine"
    requests = { cpu = "25m", memory = "32Mi" }
    limits   = { cpu = "100m", memory = "64Mi" }
  }

  guest = {
    replicas = 1
    requests = { cpu = "150m", memory = "256Mi" }
    limits   = { cpu = "400m", memory = "384Mi" }
  }

  user = {
    replicas = 1
    requests = { cpu = "150m", memory = "256Mi" }
    limits   = { cpu = "400m", memory = "384Mi" }
  }

  apigateway = {
    replicas = 1
    requests = { cpu = "150m", memory = "192Mi" }
    limits   = { cpu = "400m", memory = "320Mi" }
  }
}
