# TradingAgents 部署手册

## 1. 部署概述

TradingAgents支持多种部署模式，从本地开发到生产环境的云部署。本手册涵盖了所有主要的部署场景和最佳实践。

## 2. 系统要求

### 2.1 最低配置
- **CPU**: 4核心
- **内存**: 8GB RAM
- **存储**: 20GB可用空间
- **网络**: 稳定的互联网连接
- **操作系统**: Linux (Ubuntu 20.04+), macOS (10.15+), Windows 10+

### 2.2 推荐配置
- **CPU**: 8核心以上
- **内存**: 16GB+ RAM
- **存储**: 50GB+ SSD
- **网络**: 高速宽带连接
- **GPU**: NVIDIA GPU (可选，用于本地LLM)

### 2.3 生产环境配置
- **CPU**: 16核心以上
- **内存**: 32GB+ RAM
- **存储**: 100GB+ SSD
- **网络**: 企业级网络
- **负载均衡**: Nginx/HAProxy
- **监控**: Prometheus + Grafana

## 3. 本地部署

### 3.1 开发环境部署

#### 步骤1：环境准备
```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装Python和工具
sudo apt install python3.11 python3.11-venv python3-pip git -y

# 安装Node.js (用于某些前端组件)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install nodejs -y
```

#### 步骤2：项目部署
```bash
# 克隆项目
git clone https://github.com/TauricResearch/TradingAgents.git
cd TradingAgents

# 创建虚拟环境
python3.11 -m venv venv
source venv/bin/activate

# 安装依赖
pip install -r requirements.txt
```

#### 步骤3：配置设置
```bash
# 复制配置文件
cp .env.example .env

# 编辑配置文件
nano .env
```

`.env`文件示例：
```bash
# API密钥
OPENAI_API_KEY=your_openai_api_key_here
ALPHA_VANTAGE_API_KEY=your_alpha_vantage_api_key_here

# 可选配置
ANTHROPIC_API_KEY=your_anthropic_api_key_here
GOOGLE_API_KEY=your_google_api_key_here

# 数据目录
TRADINGAGENTS_DATA_DIR=./data
TRADINGAGENTS_RESULTS_DIR=./results

# 缓存配置
TRADINGAGENTS_CACHE_TTL=3600
```

#### 步骤4：验证部署
```bash
# 运行测试
python -m pytest test.py

# 启动CLI
python -m cli.main

# 运行示例
python main.py
```

### 3.2 Docker部署

#### 创建Dockerfile
```dockerfile
FROM python:3.11-slim

# 设置工作目录
WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 复制项目文件
COPY requirements.txt .
COPY . .

# 安装Python依赖
RUN pip install --no-cache-dir -r requirements.txt

# 创建非root用户
RUN useradd -m -u 1000 tradinguser
USER tradinguser

# 暴露端口（如果需要）
EXPOSE 8000

# 启动命令
CMD ["python", "-m", "cli.main"]
```

#### 创建docker-compose.yml
```yaml
version: '3.8'

services:
  tradingagents:
    build: .
    container_name: tradingagents
    volumes:
      - ./data:/app/data
      - ./results:/app/results
      - ./logs:/app/logs
    environment:
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - ALPHA_VANTAGE_API_KEY=${ALPHA_VANTAGE_API_KEY}
    networks:
      - tradingagents-network

  redis:
    image: redis:7-alpine
    container_name: tradingagents-redis
    volumes:
      - redis_data:/data
    networks:
      - tradingagents-network

  chromadb:
    image: chromadb/chroma:latest
    container_name: tradingagents-chroma
    volumes:
      - chromadb_data:/chroma/chroma
    ports:
      - "8001:8000"
    networks:
      - tradingagents-network

volumes:
  redis_data:
  chromadb_data:

networks:
  tradingagents-network:
    driver: bridge
```

#### 部署命令
```bash
# 构建和启动
docker-compose up -d

# 查看日志
docker-compose logs -f tradingagents

# 进入容器
docker-compose exec tradingagents bash
```

## 4. 云端部署

### 4.1 AWS部署

#### EC2部署脚本
```bash
#!/bin/bash

# AWS EC2部署脚本
# 使用Ubuntu 20.04 LTS

# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

# 安装Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 克隆项目
git clone https://github.com/TauricResearch/TradingAgents.git
cd TradingAgents

# 设置环境变量
echo "OPENAI_API_KEY=${OPENAI_API_KEY}" >> .env
echo "ALPHA_VANTAGE_API_KEY=${ALPHA_VANTAGE_API_KEY}" >> .env

# 启动服务
docker-compose up -d

# 设置自动启动
sudo systemctl enable docker
```

#### AWS ECS部署

创建ECS任务定义：
```json
{
  "family": "tradingagents",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "2048",
  "memory": "4096",
  "executionRoleArn": "arn:aws:iam::account:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::account:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "tradingagents",
      "image": "your-ecr-repo/tradingagents:latest",
      "portMappings": [
        {
          "containerPort": 8000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "OPENAI_API_KEY",
          "value": "your-api-key"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/tradingagents",
          "awslogs-region": "us-west-2",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

### 4.2 Google Cloud Platform部署

#### Cloud Run部署
```bash
# 创建Dockerfile（如上所述）
# 构建和推送镜像
gcloud builds submit --tag gcr.io/PROJECT-ID/tradingagents

# 部署到Cloud Run
gcloud run deploy tradingagents \
  --image gcr.io/PROJECT-ID/tradingagents \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars OPENAI_API_KEY=$OPENAI_API_KEY,ALPHA_VANTAGE_API_KEY=$ALPHA_VANTAGE_API_KEY
```

#### GKE部署
```yaml
# k8s-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tradingagents
spec:
  replicas: 3
  selector:
    matchLabels:
      app: tradingagents
  template:
    metadata:
      labels:
        app: tradingagents
    spec:
      containers:
      - name: tradingagents
        image: gcr.io/PROJECT-ID/tradingAgents:latest
        ports:
        - containerPort: 8000
        env:
        - name: OPENAI_API_KEY
          valueFrom:
            secretKeyRef:
              name: api-secrets
              key: openai-api-key
        - name: ALPHA_VANTAGE_API_KEY
          valueFrom:
            secretKeyRef:
              name: api-secrets
              key: alpha-vantage-api-key
        resources:
          requests:
            memory: "2Gi"
            cpu: "500m"
          limits:
            memory: "4Gi"
            cpu: "1000m"
---
apiVersion: v1
kind: Service
metadata:
  name: tradingagents-service
spec:
  selector:
    app: tradingagents
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8000
  type: LoadBalancer
```

### 4.3 Azure部署

#### Container Instances部署
```bash
# 创建资源组
az group create --name tradingagents-rg --location eastus

# 部署容器实例
az container create \
  --resource-group tradingagents-rg \
  --name tradingagents \
  --image your-registry/tradingagents:latest \
  --cpu 2 \
  --memory 4 \
  --ports 8000 \
  --environment-variables \
    OPENAI_API_KEY=$OPENAI_API_KEY \
    ALPHA_VANTAGE_API_KEY=$ALPHA_VANTAGE_API_KEY
```

## 5. 生产环境配置

### 5.1 负载均衡配置

#### Nginx配置
```nginx
upstream tradingagents {
    server 127.0.0.1:8000;
    server 127.0.0.1:8001;
    server 127.0.0.1:8002;
}

server {
    listen 80;
    server_name trading.yourdomain.com;
    
    location / {
        proxy_pass http://tradingagents;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # 静态文件
    location /static/ {
        alias /var/www/tradingagents/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

### 5.2 数据库配置

#### Redis缓存配置
```bash
# Redis配置文件 redis.conf
maxmemory 2gb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000
```

#### ChromaDB配置
```python
# 生产环境ChromaDB配置
import chromadb
from chromadb.config import Settings

client = chromadb.HttpClient(
    host="localhost",
    port=8000,
    settings=Settings(
        allow_reset=True,
        anonymized_telemetry=False,
        chroma_db_impl="duckdb+parquet",
        persist_directory="./chroma_db"
    )
)
```

### 5.3 监控配置

#### Prometheus配置
```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'tradingagents'
    static_configs:
      - targets: ['localhost:8000']
    metrics_path: '/metrics'
    scrape_interval: 30s
```

#### Grafana仪表板配置
```json
{
  "dashboard": {
    "title": "TradingAgents Monitoring",
    "panels": [
      {
        "title": "API Response Time",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))"
          }
        ]
      },
      {
        "title": "Active Agents",
        "type": "stat",
        "targets": [
          {
            "expr": "tradingagents_active_agents"
          }
        ]
      }
    ]
  }
}
```

## 6. 安全配置

### 6.1 API密钥管理

#### 使用AWS Secrets Manager
```python
import boto3
import json

def get_secret(secret_name):
    client = boto3.client('secretsmanager')
    response = client.get_secret_value(SecretId=secret_name)
    return json.loads(response['SecretString'])

# 使用密钥
secrets = get_secret('tradingagents/api-keys')
openai_key = secrets['OPENAI_API_KEY']
```

#### 使用HashiCorp Vault
```python
import hvac

def get_vault_secret(path, key):
    client = hvac.Client(url='https://vault.yourdomain.com')
    client.auth.approle.login(
        role_id='your-role-id',
        secret_id='your-secret-id'
    )
    return client.read(f'secret/data/{path}')['data'][key]
```

### 6.2 网络安全

#### 防火墙配置
```bash
# UFW配置
sudo ufw enable
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw deny 8000/tcp   # 直接访问应用端口
```

#### SSL/TLS配置
```bash
# 使用Let's Encrypt
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d trading.yourdomain.com
```

## 7. 备份和恢复

### 7.1 数据备份策略

#### 自动备份脚本
```bash
#!/bin/bash
# backup.sh

BACKUP_DIR="/backup/tradingagents"
DATE=$(date +%Y%m%d_%H%M%S)

# 创建备份目录
mkdir -p $BACKUP_DIR

# 备份数据
tar -czf $BACKUP_DIR/data_$DATE.tar.gz ./data
tar -czf $BACKUP_DIR/results_$DATE.tar.gz ./results

# 备份数据库
docker exec tradingagents-chroma tar -czf /backup/chroma_$DATE.tar.gz /chroma/chroma

# 清理旧备份（保留30天）
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete

# 上传到云存储
aws s3 cp $BACKUP_DIR s3://your-backup-bucket/tradingagents/ --recursive
```

#### 恢复脚本
```bash
#!/bin/bash
# restore.sh

BACKUP_FILE=$1
RESTORE_DIR="/tmp/restore"

mkdir -p $RESTORE_DIR

# 从云存储下载
aws s3 cp s3://your-backup-bucket/tradingagents/$BACKUP_FILE $RESTORE_DIR/

# 恢复数据
tar -xzf $RESTORE_DIR/$BACKUP_FILE -C ./

# 重启服务
docker-compose restart
```

## 8. 性能优化

### 8.1 系统优化

#### 内核参数优化
```bash
# /etc/sysctl.conf
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
vm.swappiness = 10
```

#### Docker优化
```yaml
# docker-compose.yml优化
version: '3.8'

services:
  tradingagents:
    build: .
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          cpus: '1.0'
          memory: 2G
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### 8.2 应用优化

#### 缓存策略
```python
# 配置Redis缓存
import redis
import pickle

redis_client = redis.Redis(host='localhost', port=6379, db=0)

def cache_result(key_func, ttl=3600):
    def decorator(func):
        def wrapper(*args, **kwargs):
            cache_key = key_func(*args, **kwargs)
            
            # 尝试从缓存获取
            cached = redis_client.get(cache_key)
            if cached:
                return pickle.loads(cached)
            
            # 执行函数并缓存结果
            result = func(*args, **kwargs)
            redis_client.setex(cache_key, ttl, pickle.dumps(result))
            return result
        return wrapper
    return decorator
```

## 9. 故障排除

### 9.1 常见问题诊断

#### 健康检查脚本
```bash
#!/bin/bash
# health_check.sh

echo "=== TradingAgents Health Check ==="

# 检查服务状态
echo "Checking services..."
docker-compose ps

# 检查资源使用
echo "Checking resource usage..."
docker stats --no-stream

# 检查日志错误
echo "Checking for errors..."
docker-compose logs --tail=50 tradingagents | grep -i error

# 检查API连接
echo "Checking API connectivity..."
curl -f http://localhost:8000/health || echo "API health check failed"

# 检查磁盘空间
echo "Checking disk space..."
df -h

echo "=== Health Check Complete ==="
```

#### 性能监控脚本
```bash
#!/bin/bash
# performance_monitor.sh

while true; do
    echo "$(date): Collecting metrics..."
    
    # CPU使用率
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    echo "CPU: $CPU_USAGE%"
    
    # 内存使用率
    MEM_USAGE=$(free | grep Mem | awk '{printf("%.1f"), $3/$2 * 100.0}')
    echo "Memory: $MEM_USAGE%"
    
    # API响应时间
    RESPONSE_TIME=$(curl -o /dev/null -s -w '%{time_total}' http://localhost:8000/health)
    echo "API Response Time: ${RESPONSE_TIME}s"
    
    sleep 60
done
```

## 10. 升级和维护

### 10.1 滚动升级

#### 零停机升级脚本
```bash
#!/bin/bash
# rolling_upgrade.sh

NEW_VERSION=$1
CURRENT_VERSION=$(docker-compose images -q tradingagents | head -1)

echo "Upgrading from $CURRENT_VERSION to $NEW_VERSION"

# 拉取新镜像
docker-compose pull tradingagents

# 逐个升级实例
for i in {1..3}; do
    echo "Upgrading instance $i..."
    
    # 停止实例
    docker-compose stop tradingagents_$i
    
    # 升级实例
    docker-compose up -d --scale tradingagents_$i=1
    
    # 等待健康检查
    sleep 30
    
    # 验证服务
    if curl -f http://localhost:8000/health; then
        echo "Instance $i upgraded successfully"
    else
        echo "Instance $i upgrade failed, rolling back..."
        docker-compose stop tradingagents_$i
        docker run --name tradingagents_$i_rollback $CURRENT_VERSION
        exit 1
    fi
done

echo "Upgrade completed successfully"
```

### 10.2 定期维护任务

#### 维护脚本
```bash
#!/bin/bash
# maintenance.sh

echo "Starting maintenance tasks..."

# 清理Docker镜像
docker system prune -f

# 清理日志文件
find ./logs -name "*.log" -mtime +7 -delete

# 优化数据库
docker exec tradingagents-chroma chromadb utils migrate

# 重启服务（如果需要）
docker-compose restart

echo "Maintenance completed"
```

这个部署手册提供了从本地开发到生产环境的完整部署指南，确保TradingAgents能够在各种环境中稳定运行。