k8s_resources = {
  storage_class = "gp3" # EBS CSI StorageClass created by Terraform

  redis = {
    replicas = 1
    requests = { cpu = "25m", memory = "64Mi" }
    limits   = { cpu = "100m", memory = "128Mi" }
  }

  rabbitmq = {
    replicas = 1
    requests = { cpu = "100m", memory = "192Mi" }
    limits   = { cpu = "250m", memory = "320Mi" }
  }

  n8n = {
    replicas = 1
    requests = { cpu = "150m", memory = "256Mi" }
    limits   = { cpu = "300m", memory = "384Mi" }
  }

  n8n_proxy = {
    replicas = 1
    image    = "936910352865.dkr.ecr.us-east-1.amazonaws.com/dockerhub/nginx:1.27-alpine"
    requests = { cpu = "25m", memory = "32Mi" }
    limits   = { cpu = "100m", memory = "64Mi" }
  }

  guest = {
    replicas = 1
    requests = { cpu = "100m", memory = "192Mi" }
    limits   = { cpu = "250m", memory = "256Mi" }
  }

  user = {
    replicas = 1
    requests = { cpu = "100m", memory = "192Mi" }
    limits   = { cpu = "250m", memory = "256Mi" }
  }

  apigateway = {
    replicas = 1
    requests = { cpu = "100m", memory = "160Mi" }
    limits   = { cpu = "250m", memory = "256Mi" }
  }
}
