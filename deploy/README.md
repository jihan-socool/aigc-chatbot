# 部署配置文档 / Deployment Configuration

本目录包含生产环境部署相关的配置文件和文档。

## 文件说明

### `.env.tencent.production.example`

这是面向腾讯云 CVM（云服务器）生产部署的完整环境变量模板，包含以下配置：

#### 核心配置

- **应用配置**：NODE_ENV, PORT, NEXTAUTH_URL
- **数据库**：POSTGRES_URL（支持腾讯云数据库 for PostgreSQL）
- **认证安全**：AUTH_SECRET, NEXTAUTH_SECRET
- **AI 提供商**：OpenAI 兼容接口配置，支持自定义网关

#### 可选服务

- **AI Gateway**：用于路由和监控（AI_GATEWAY_API_KEY）
- **Redis**：缓存和可恢复流式传输（REDIS_URL）
- **Blob 存储**：文件上传功能（BLOB_READ_WRITE_TOKEN）

#### Tencent 专属

- **CCR 容器镜像仓库**：CCR_REGISTRY, CCR_NAMESPACE, CCR_REPOSITORY
- **Docker Hub 镜像**：DOCKER_HUB_MIRROR（国内加速）
- **SSH 部署**：SSH_HOST, SSH_PORT, SSH_USER, DEPLOY_PATH
- **CI/CD 变量**：DEPLOY_BRANCH, AUTO_DEPLOY, ENVIRONMENT
- **腾讯云 API**：TENCENT_SECRET_ID, TENCENT_SECRET_KEY, TENCENT_REGION

#### 生产优化

- 安全头配置
- 速率限制
- CORS 设置
- 特性开关

## 使用步骤

### 1. 准备环境变量

```bash
# 从模板复制
cp deploy/.env.tencent.production.example .env.production

# 编辑并填写实际值
vim .env.production

# 设置安全权限
chmod 600 .env.production
```

### 2. 生成密钥

```bash
# 生成 AUTH_SECRET
openssl rand -base64 32

# 或使用在线工具
# https://generate-secret.vercel.app/32
```

### 3. 配置必需服务

#### PostgreSQL 数据库

腾讯云数据库 for PostgreSQL 连接格式：

```
postgresql://username:password@instance-id.pgsql.tencentcdb.com:5432/database?sslmode=require
```

#### Redis（可选）

腾讯云数据库 Redis 版连接格式：

```
redis://:password@instance-id.redis.tencentcdb.com:6379
```

### 4. 配置容器镜像仓库

登录腾讯云容器镜像服务（CCR）：

```bash
docker login ccr.ccs.tencentyun.com
```

设置环境变量：

```
CCR_REGISTRY=ccr.ccs.tencentyun.com
CCR_NAMESPACE=your-namespace
CCR_REPOSITORY=chatapp
```

### 5. SSH 部署配置

确保目标 CVM 实例已配置：

1. SSH 密钥认证
2. Docker 和 Docker Compose 安装
3. 部署目录权限（如 `/opt/chatapp`）
4. 防火墙规则（开放应用端口）

### 6. CI/CD 集成

将以下变量配置为 CI/CD 平台的加密环境变量：

- `SSH_PRIVATE_KEY`：SSH 私钥（Base64 编码）
- `AUTH_SECRET`：应用密钥
- `POSTGRES_URL`：数据库连接串
- `OPENAI_API_KEY`：AI 提供商密钥
- `TENCENT_SECRET_ID` / `TENCENT_SECRET_KEY`：腾讯云 API 凭证

## 安全建议

1. **永远不要提交 `.env.production` 到版本控制**
2. 使用强随机密钥（至少 32 字节）
3. 定期轮换密钥和密码
4. 使用最小权限原则配置数据库和 API 访问
5. 在 CI/CD 平台使用加密变量存储敏感信息
6. 启用 SSL/TLS 连接（数据库、Redis、API）
7. 配置防火墙和安全组规则

## 验证部署

部署后验证以下检查点：

```bash
# 1. 检查应用健康状态
curl https://your-domain.com/api/health

# 2. 检查数据库连接
# 登录应用并测试用户创建和聊天历史

# 3. 检查 AI 模型调用
# 发送测试消息并验证响应

# 4. 检查文件上传（如启用）
# 上传图片附件并验证存储

# 5. 查看应用日志
docker logs <container-name>
# 或
journalctl -u chatapp -f
```

## 故障排查

### 数据库连接失败

- 检查 POSTGRES_URL 格式
- 验证数据库防火墙规则
- 确认 SSL 模式配置

### AI API 调用失败

- 验证 OPENAI_API_KEY 有效性
- 检查 OPENAI_API_URL 可访问性
- 测试模型 ID 是否正确

### 文件上传失败

- 确认 BLOB_READ_WRITE_TOKEN 配置
- 检查存储服务配额
- 验证 CORS 设置

## 相关文档

- [腾讯云容器镜像服务 CCR](https://cloud.tencent.com/document/product/1141)
- [腾讯云数据库 PostgreSQL](https://cloud.tencent.com/document/product/409)
- [腾讯云数据库 Redis](https://cloud.tencent.com/document/product/239)
- [腾讯云对象存储 COS](https://cloud.tencent.com/document/product/436)
- [Next.js 部署文档](https://nextjs.org/docs/deployment)
- [NextAuth.js 配置](https://next-auth.js.org/configuration/options)

## 技术支持

如有部署问题，请在项目 Issues 中反馈，并附上：

1. 部署环境信息（OS、Docker 版本等）
2. 相关错误日志（脱敏后）
3. 已尝试的解决步骤

---

**注意**：本模板适配腾讯云 CVM 部署场景，如使用其他云平台或本地部署，请根据实际情况调整配置。
