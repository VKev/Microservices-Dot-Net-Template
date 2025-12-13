# This file is automatically sanitized.
# Run scripts/sanitize_tfvars.py after editing real tfvars.

eks_cluster_version = "1.34"

eks_cluster_endpoint_public_access = true

eks_cluster_endpoint_private_access = true

eks_node_instance_types = [
  "t3.small"
]

eks_node_min_size = 2

eks_node_max_size = 5

eks_node_desired_size = 4

eks_node_capacity_type = "ON_DEMAND"

environment = "dev"

eks_enable_cluster_creator_admin_permissions = true

eks_create_cloudwatch_log_group = false

eks_default_storage_class_name = "gp2"

eks_ebs_volume_type = "gp3"

k8s_resources = {
  storage_class = "gp3"
  redis = {
    replicas = 1
    requests = {
      cpu    = "25m"
      memory = "64Mi"
    }
    limits = {
      cpu    = "100m"
      memory = "128Mi"
    }
  }
  rabbitmq = {
    replicas = 1
    requests = {
      cpu    = "100m"
      memory = "192Mi"
    }
    limits = {
      cpu    = "250m"
      memory = "320Mi"
    }
  }
  n8n = {
    replicas = 1
    requests = {
      cpu    = "150m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "300m"
      memory = "384Mi"
    }
  }
  n8n_proxy = {
    replicas = 1
    requests = {
      cpu    = "25m"
      memory = "32Mi"
    }
    limits = {
      cpu    = "100m"
      memory = "64Mi"
    }
  }
  guest = {
    replicas = 1
    requests = {
      cpu    = "100m"
      memory = "192Mi"
    }
    limits = {
      cpu    = "250m"
      memory = "256Mi"
    }
  }
  user = {
    replicas = 1
    requests = {
      cpu    = "100m"
      memory = "192Mi"
    }
    limits = {
      cpu    = "250m"
      memory = "256Mi"
    }
  }
  apigateway = {
    replicas = 1
    requests = {
      cpu    = "100m"
      memory = "160Mi"
    }
    limits = {
      cpu    = "250m"
      memory = "256Mi"
    }
  }
}

k8s_microservices_manifest = <<-EOT
apiVersion: v1
kind: Namespace
metadata:
  name: microservices
---
apiVersion: v1
kind: Secret
metadata:
  name: redis-auth
  namespace: TERRAFORM_NAMESPACE
type: Opaque
stringData:
  redis-password: "<REDACTED>"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: redis-data
  namespace: TERRAFORM_NAMESPACE
spec:
  storageClassName: gp3
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: TERRAFORM_NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
        - name: redis
          image: your-aws-id.dkr.ecr.us-east-1.amazonaws.com/dockerhub/library/redis:alpine
          ports:
            - containerPort: 6379
          env:
            - name: REDIS_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: redis-auth
                  key: redis-password
          resources:
            requests:
              cpu: 25m
              memory: 64Mi
            limits:
              cpu: 100m
              memory: 128Mi
          command: ['sh', '-c', 'exec redis-server --requirepass "$REDIS_PASSWORD"']
          livenessProbe:
            exec:
              command: ['sh', '-c', 'redis-cli -a "$REDIS_PASSWORD" ping']
            initialDelaySeconds: 10
            periodSeconds: 10
          readinessProbe:
            exec:
              command: ['sh', '-c', 'redis-cli -a "$REDIS_PASSWORD" ping']
            initialDelaySeconds: 5
            periodSeconds: 10
          volumeMounts:
            - name: redis-data
              mountPath: /data
      volumes:
        - name: redis-data
          persistentVolumeClaim:
            claimName: redis-data
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: TERRAFORM_NAMESPACE
spec:
  type: NodePort
  selector:
    app: redis
  ports:
    - port: 6379
      targetPort: 6379
      nodePort: 30379
---
apiVersion: v1
kind: Secret
metadata:
  name: rabbitmq-auth
  namespace: TERRAFORM_NAMESPACE
type: Opaque
stringData:
  rabbitmq-username: "rabbitmq"
  rabbitmq-password: "<REDACTED>"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rabbitmq-data
  namespace: TERRAFORM_NAMESPACE
spec:
  storageClassName: gp3
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rabbitmq
  namespace: TERRAFORM_NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rabbitmq
  template:
    metadata:
      labels:
        app: rabbitmq
    spec:
      containers:
        - name: rabbit-mq
          image: your-aws-id.dkr.ecr.us-east-1.amazonaws.com/dockerhub/library/rabbitmq:3-management
          ports:
            - containerPort: 5672
            - containerPort: 15672
          startupProbe:
            exec:
              command: ["rabbitmqctl", "status"]
            initialDelaySeconds: 15
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 6
          env:
            - name: RABBITMQ_DEFAULT_USER
              valueFrom:
                secretKeyRef:
                  name: rabbitmq-auth
                  key: rabbitmq-username
            - name: RABBITMQ_DEFAULT_PASS
              valueFrom:
                secretKeyRef:
                  name: rabbitmq-auth
                  key: rabbitmq-password
          resources:
            requests:
              cpu: 100m
              memory: 192Mi
            limits:
              cpu: 250m
              memory: 320Mi
          livenessProbe:
            exec:
              command: ["rabbitmq-diagnostics", "-q", "ping"]
            initialDelaySeconds: 120
            periodSeconds: 30
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            exec:
              command: ["rabbitmq-diagnostics", "-q", "ping"]
            initialDelaySeconds: 30
            periodSeconds: 15
            timeoutSeconds: 5
            failureThreshold: 15
          volumeMounts:
            - name: rabbitmq-data
              mountPath: /var/lib/rabbitmq
      volumes:
        - name: rabbitmq-data
          persistentVolumeClaim:
            claimName: rabbitmq-data
---
apiVersion: v1
kind: Service
metadata:
  name: rabbit-mq
  namespace: TERRAFORM_NAMESPACE
spec:
  type: NodePort
  selector:
    app: rabbitmq
  ports:
    - name: amqp
      port: 5672
      targetPort: 5672
      nodePort: 30672
    - name: management
      port: 15672
      targetPort: 15672
      nodePort: 31672
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: n8n-data
  namespace: TERRAFORM_NAMESPACE
spec:
  storageClassName: gp3
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: n8n
  namespace: TERRAFORM_NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: n8n
  template:
    metadata:
      labels:
        app: n8n
    spec:
      securityContext:
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        fsGroupChangePolicy: "OnRootMismatch"
      containers:
        - name: n8n
          image: your-aws-id.dkr.ecr.us-east-1.amazonaws.com/dockerhub/n8nio/n8n:latest
          env:
            - name: N8N_HOST
              value: "0.0.0.0"
            - name: N8N_PORT
              value: "5678"
            - name: N8N_PROTOCOL
              value: "http"
            - name: N8N_SECURE_COOKIE
              value: "false"
            - name: N8N_PATH
              value: "/n8n/"
            - name: N8N_DB_TYPE
              value: "postgresdb"
            - name: N8N_DB_POSTGRESDB_HOST
              value: "TERRAFORM_RDS_HOST_USER_N8NDB"
            - name: N8N_DB_POSTGRESDB_PORT
              value: "TERRAFORM_RDS_PORT_USER_N8NDB"
            - name: N8N_DB_POSTGRESDB_DATABASE
              value: "TERRAFORM_RDS_DB_USER_N8NDB"
            - name: N8N_DB_POSTGRESDB_USER
              value: "TERRAFORM_RDS_USERNAME_USER_N8NDB"
            - name: N8N_DB_POSTGRESDB_PASSWORD
              value: "TERRAFORM_RDS_PASSWORD_USER_N8NDB"
            - name: GENERIC_TIMEZONE
              value: "Asia/Ho_Chi_Minh"
            - name: TZ
              value: "Asia/Ho_Chi_Minh"
            - name: N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS
              value: "true"
            - name: N8N_DIAGNOSTICS_ENABLED
              value: "false"
            - name: N8N_VERSION_NOTIFICATIONS_ENABLED
              value: "false"
            - name: N8N_TEMPLATES_ENABLED
              value: "false"
            - name: N8N_METRICS
              value: "true"
            - name: QUEUE_HEALTH_CHECK_ACTIVE
              value: "true"
            - name: NODE_OPTIONS
              value: "--max-old-space-size=512"
            - name: N8N_EDITOR_BASE_URL
              value: "http://localhost:5678/n8n/"
            - name: WEBHOOK_URL
              value: "http://localhost:5678/n8n/"
            - name: VUE_APP_URL_BASE_API
              value: "http://localhost:5678/n8n/"
          resources:
            requests:
              cpu: 150m
              memory: 256Mi
            limits:
              cpu: 300m
              memory: 384Mi
          ports:
            - containerPort: 5678
          livenessProbe:
            httpGet:
              path: /healthz
              port: 5678
            initialDelaySeconds: 20
            periodSeconds: 15
          readinessProbe:
            httpGet:
              path: /healthz
              port: 5678
            initialDelaySeconds: 10
            periodSeconds: 10
          volumeMounts:
            - name: n8n-data
              mountPath: /home/node/.n8n
      volumes:
        - name: n8n-data
          persistentVolumeClaim:
            claimName: n8n-data
---
apiVersion: v1
kind: Service
metadata:
  name: n8n
  namespace: TERRAFORM_NAMESPACE
spec:
  type: ClusterIP
  selector:
    app: n8n
  ports:
    - port: 5678
      targetPort: 5678
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: n8n-nginx-conf
  namespace: TERRAFORM_NAMESPACE
data:
  nginx.conf: |
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
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: n8n-proxy
  namespace: TERRAFORM_NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: n8n-proxy
  template:
    metadata:
      labels:
        app: n8n-proxy
    spec:
      containers:
        - name: nginx
          image: your-aws-id.dkr.ecr.us-east-1.amazonaws.com/dockerhub/library/nginx:1.27-alpine
          ports:
            - containerPort: 5678
          resources:
            requests:
              cpu: 25m
              memory: 32Mi
            limits:
              cpu: 100m
              memory: 64Mi
          volumeMounts:
            - name: nginx-conf
              mountPath: /etc/nginx/nginx.conf
              subPath: nginx.conf
      volumes:
        - name: nginx-conf
          configMap:
            name: n8n-nginx-conf
---
apiVersion: v1
kind: Service
metadata:
  name: n8n-proxy
  namespace: TERRAFORM_NAMESPACE
spec:
  type: NodePort
  selector:
    app: n8n-proxy
  ports:
    - port: 5678
      targetPort: 5678
      nodePort: 30578
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: guest-microservice
  namespace: TERRAFORM_NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: guest-microservice
  template:
    metadata:
      labels:
        app: guest-microservice
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                topologyKey: kubernetes.io/hostname
                labelSelector:
                  matchLabels:
                    app: guest-microservice
      containers:
        - name: guest-microservice
          image: your-aws-id.dkr.ecr.us-east-1.amazonaws.com/vkev2406-infrastructure-khanghv2406-infrastructure-khanghv2406-ecr:Guest.Microservice-latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 5001
          env:
            - name: ASPNETCORE_ENVIRONMENT
              value: Production
            - name: ASPNETCORE_URLS
              value: http://+:5001
            - name: Database__Host
              value: "TERRAFORM_RDS_HOST_GUEST_DEFAULTDB"
            - name: Database__Port
              value: "TERRAFORM_RDS_PORT_GUEST_DEFAULTDB"
            - name: Database__Name
              value: "TERRAFORM_RDS_DB_GUEST_DEFAULTDB"
            - name: Database__Username
              value: "TERRAFORM_RDS_USERNAME_GUEST_DEFAULTDB"
            - name: Database__Password
              value: "TERRAFORM_RDS_PASSWORD_GUEST_DEFAULTDB"
            - name: Database__Provider
              value: "TERRAFORM_RDS_PROVIDER_GUEST_DEFAULTDB"
            - name: RabbitMq__Host
              value: rabbit-mq
            - name: RabbitMq__Port
              value: "5672"
            - name: RabbitMq__Username
              value: rabbitmq
            - name: RabbitMq__Password
              value: "<REDACTED>"
            - name: Redis__Host
              value: redis
            - name: Redis__Password
              value: "<REDACTED>"
            - name: Redis__Port
              value: "6379"
            - name: Jwt__SecretKey
              value: "<REDACTED>"
            - name: Jwt__Issuer
              value: UserMicroservice
            - name: Jwt__Audience
              value: MicroservicesApp
            - name: Jwt__ExpirationMinutes
              value: "60"
            - name: AutoApply__Migrations
              value: "true"
          resources:
            requests:
              cpu: 100m
              memory: 192Mi
            limits:
              cpu: 250m
              memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: guest-microservice
  namespace: TERRAFORM_NAMESPACE
spec:
  selector:
    app: guest-microservice
  ports:
    - port: 5001
      targetPort: 5001
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-microservice
  namespace: TERRAFORM_NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: user-microservice
  template:
    metadata:
      labels:
        app: user-microservice
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                topologyKey: kubernetes.io/hostname
                labelSelector:
                  matchLabels:
                    app: user-microservice
      containers:
        - name: user-microservice
          image: your-aws-id.dkr.ecr.us-east-1.amazonaws.com/vkev2406-infrastructure-khanghv2406-infrastructure-khanghv2406-ecr:User.Microservice-latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 5002
          env:
            - name: ASPNETCORE_ENVIRONMENT
              value: Production
            - name: ASPNETCORE_URLS
              value: http://+:5002
            - name: Database__Host
              value: "TERRAFORM_RDS_HOST_USER_DEFAULTDB"
            - name: Database__Port
              value: "TERRAFORM_RDS_PORT_USER_DEFAULTDB"
            - name: Database__Name
              value: "TERRAFORM_RDS_DB_USER_DEFAULTDB"
            - name: Database__Username
              value: "TERRAFORM_RDS_USERNAME_USER_DEFAULTDB"
            - name: Database__Password
              value: "TERRAFORM_RDS_PASSWORD_USER_DEFAULTDB"
            - name: Database__Provider
              value: "TERRAFORM_RDS_PROVIDER_USER_DEFAULTDB"
            - name: Database__SslMode
              value: "TERRAFORM_RDS_SSLMODE_USER_DEFAULTDB"
            - name: RabbitMq__Host
              value: rabbit-mq
            - name: RabbitMq__Port
              value: "5672"
            - name: RabbitMq__Username
              value: rabbitmq
            - name: RabbitMq__Password
              value: "<REDACTED>"
            - name: Redis__Host
              value: redis
            - name: Redis__Password
              value: "<REDACTED>"
            - name: Redis__Port
              value: "6379"
            - name: Jwt__SecretKey
              value: "<REDACTED>"
            - name: Jwt__Issuer
              value: UserMicroservice
            - name: Jwt__Audience
              value: MicroservicesApp
            - name: Jwt__ExpirationMinutes
              value: "60"
            - name: Cors__AllowedOrigins__0
              value: http://localhost:5173
            - name: Cors__AllowedOrigins__1
              value: https://your-frontend.example.com
            - name: Cors__AllowedOrigins__2
              value: http://localhost:2406
            - name: AutoApply__Migrations
              value: "true"
          resources:
            requests:
              cpu: 100m
              memory: 192Mi
            limits:
              cpu: 250m
              memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: user-microservice
  namespace: TERRAFORM_NAMESPACE
spec:
  selector:
    app: user-microservice
  ports:
    - port: 5002
      targetPort: 5002
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  namespace: TERRAFORM_NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                topologyKey: kubernetes.io/hostname
                labelSelector:
                  matchLabels:
                    app: api-gateway
      containers:
        - name: api-gateway
          image: your-aws-id.dkr.ecr.us-east-1.amazonaws.com/vkev2406-infrastructure-khanghv2406-infrastructure-khanghv2406-ecr:ApiGateway-latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8080
          env:
            - name: ENABLE_SWAGGER_UI
              value: "true"
            - name: ASPNETCORE_ENVIRONMENT
              value: Production
            - name: ASPNETCORE_URLS
              value: http://+:8080
            - name: Services__User__Host
              value: user-microservice
            - name: Services__User__Port
              value: "5002"
            - name: Services__Guest__Host
              value: guest-microservice
            - name: Services__Guest__Port
              value: "5001"
            - name: Jwt__SecretKey
              value: "<REDACTED>"
            - name: Jwt__Issuer
              value: UserMicroservice
            - name: Jwt__Audience
              value: MicroservicesApp
            - name: Jwt__ExpirationMinutes
              value: "60"
          resources:
            requests:
              cpu: 100m
              memory: 160Mi
            limits:
              cpu: 250m
              memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: api-gateway
  namespace: TERRAFORM_NAMESPACE
spec:
  type: NodePort
  selector:
    app: api-gateway
  ports:
    - port: 8080
      targetPort: 8080
      nodePort: 32080
EOT
