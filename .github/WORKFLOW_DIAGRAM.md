# CI/CD Workflow Diagram

Visual representation of the GitHub Actions deployment workflow.

## Overall Architecture

```
┌─────────────────┐
│  Developer      │
│  Local Machine  │
└────────┬────────┘
         │
         │ git push origin main
         │
         ▼
┌─────────────────────────────────────────────────┐
│           GitHub Repository                      │
│  ┌─────────────────────────────────────────┐   │
│  │     GitHub Actions Workflow             │   │
│  │  (.github/workflows/deploy.yml)         │   │
│  └─────────────────────────────────────────┘   │
└────────┬────────────────────────────────────────┘
         │
         │ Triggered
         │
         ▼
┌─────────────────────────────────────────────────┐
│         GitHub Actions Runner                    │
│  (Ubuntu Latest)                                 │
│                                                  │
│  1. Checkout Code                                │
│  2. Setup Node.js & pnpm                         │
│  3. Setup Docker Buildx                          │
│  4. Build Docker Image                           │
│  5. Login to CCR                                 │
│  6. Push to CCR                                  │
└────────┬────────────────────────────────────────┘
         │
         │ Image pushed
         │
         ▼
┌─────────────────────────────────────────────────┐
│    Tencent Cloud Container Registry (CCR)       │
│  ccr.ccs.tencentyun.com/namespace/repository    │
│                                                  │
│  Tags: latest, <commit-sha>                      │
└────────┬────────────────────────────────────────┘
         │
         │ SSH to CVM
         │
         ▼
┌─────────────────────────────────────────────────┐
│    Tencent Cloud Virtual Machine (CVM)          │
│                                                  │
│  1. Docker login to CCR                          │
│  2. docker-compose pull                          │
│  3. docker-compose down (remove old)             │
│  4. docker-compose up -d (start new)             │
└────────┬────────────────────────────────────────┘
         │
         │ Running
         │
         ▼
┌─────────────────────────────────────────────────┐
│          Application Running                     │
│  http://your-cvm-ip:3000                         │
└─────────────────────────────────────────────────┘
```

## Detailed Workflow Steps

```
GitHub Actions Workflow Execution
════════════════════════════════════════════════════

Step 1: Trigger
───────────────────────────────────────────────────
Trigger Type:
  • Push to main branch (automatic)
  • Manual workflow dispatch (manual)

Step 2: Checkout & Setup
───────────────────────────────────────────────────
┌─────────────────────────┐
│ actions/checkout@v4     │  Clone repository
├─────────────────────────┤
│ pnpm/action-setup@v2    │  Setup pnpm 9.12.3
├─────────────────────────┤
│ actions/setup-node@v4   │  Setup Node.js 20
└─────────────────────────┘

Step 3: Docker Configuration
───────────────────────────────────────────────────
┌────────────────────────────────────┐
│ docker/setup-buildx-action@v3      │
│                                    │
│ • Multi-platform support           │
│ • Layer caching                    │
│ • Optional Docker Hub mirror       │
└────────────────────────────────────┘

Step 4: Registry Authentication
───────────────────────────────────────────────────
┌────────────────────────────────────┐
│ docker/login-action@v3             │
│                                    │
│ Registry: $CCR_REGISTRY            │
│ Username: $CCR_USERNAME            │
│ Password: $CCR_PASSWORD            │
└────────────────────────────────────┘

Step 5: Build & Push
───────────────────────────────────────────────────
┌────────────────────────────────────┐
│ docker/build-push-action@v5        │
│                                    │
│ Context: .                         │
│ Push: true                         │
│ Tags:                              │
│   • latest                         │
│   • <commit-sha>                   │
│                                    │
│ Cache:                             │
│   • From: GitHub Actions cache     │
│   • To: GitHub Actions cache       │
└────────────────────────────────────┘

Step 6: Deploy to CVM
───────────────────────────────────────────────────
┌────────────────────────────────────┐
│ appleboy/ssh-action@master         │
│                                    │
│ Host: $DEPLOY_SSH_HOST             │
│ User: $DEPLOY_SSH_USER             │
│ Port: $DEPLOY_SSH_PORT             │
│ Key:  $DEPLOY_SSH_KEY              │
│                                    │
│ Commands:                          │
│   cd /app                          │
│   docker login CCR                 │
│   docker-compose pull              │
│   docker-compose up -d             │
└────────────────────────────────────┘
```

## Docker Image Build Process

```
Docker Multi-Stage Build
═══════════════════════════════════════════════════

┌─────────────────────────────────────────────────┐
│  Stage 1: Builder (node:20-alpine)              │
│                                                  │
│  1. Install pnpm via corepack                    │
│  2. Copy package files                           │
│  3. Install dependencies                         │
│  4. Copy source code                             │
│  5. Run database migrations (tsx lib/db/migrate) │
│  6. Build Next.js app (next build)               │
└────────┬────────────────────────────────────────┘
         │
         │ Only copy built artifacts
         │
         ▼
┌─────────────────────────────────────────────────┐
│  Stage 2: Runtime (node:20-alpine)              │
│                                                  │
│  1. Install pnpm                                 │
│  2. Copy package files                           │
│  3. Install production dependencies only         │
│  4. Copy .next, public, etc from builder         │
│  5. Setup health check endpoint                  │
│  6. Expose port 3000                             │
│  7. Start: pnpm start                            │
└─────────────────────────────────────────────────┘
```

## Deployment on CVM

```
Docker Compose Orchestration
═══════════════════════════════════════════════════

┌─────────────────────────────────────────────────┐
│  /app/docker-compose.yml                         │
│                                                  │
│  Services:                                       │
│    app:                                          │
│      • Image: CCR registry image                 │
│      • Container: ai-chatbot                     │
│      • Ports: 3000:3000                          │
│      • Env: .env.production                      │
│      • Health check: HTTP GET localhost:3000     │
│      • Restart: unless-stopped                   │
│      • Logging: 10MB × 3 files                   │
│      • Network: app-network                      │
└─────────────────────────────────────────────────┘

Deployment Flow:
  1. Pull latest image from CCR
  2. Stop old container (ai-chatbot)
  3. Remove old container
  4. Create new container with new image
  5. Start new container
  6. Health check validates startup
  7. Old logs retained, new logs start
```

## Required GitHub Secrets Flow

```
GitHub Secrets → Workflow Variables
═══════════════════════════════════════════════════

CCR Authentication:
  CCR_REGISTRY ──────────────┐
  CCR_NAMESPACE ─────────────┤
  CCR_REPOSITORY ────────────┼──▶ Image URL
  CCR_USERNAME ──────────────┤
  CCR_PASSWORD ──────────────┘

SSH Connection:
  DEPLOY_SSH_HOST ───────────┐
  DEPLOY_SSH_USER ───────────┤
  DEPLOY_SSH_PORT ───────────┼──▶ SSH Connection
  DEPLOY_SSH_KEY ────────────┘

Optional:
  DOCKER_HUB_MIRROR ─────────▶ Faster image pulls
```

## Network Flow

```
Internet Traffic Flow
═══════════════════════════════════════════════════

                    ┌──────────────┐
                    │   Internet   │
                    └──────┬───────┘
                           │
                           │ HTTP/HTTPS
                           │
                    ┌──────▼───────┐
                    │  CVM Public  │
                    │      IP      │
                    └──────┬───────┘
                           │
                    Port 3000 mapping
                           │
                    ┌──────▼───────┐
                    │   Docker     │
                    │  Container   │
                    │  (ai-chatbot)│
                    └──────┬───────┘
                           │
                    Internal network
                           │
            ┌──────────────┴──────────────┐
            │                             │
     ┌──────▼───────┐            ┌────────▼────────┐
     │  PostgreSQL  │            │     Redis       │
     │   Database   │            │     Cache       │
     └──────────────┘            └─────────────────┘
```

## Rollback Process

```
Rollback to Previous Version
═══════════════════════════════════════════════════

Option 1: Redeploy specific commit
───────────────────────────────────────────────────
1. Go to GitHub → Actions → Select workflow
2. Click "Run workflow"
3. Choose the commit/branch to deploy
4. Workflow rebuilds and deploys that version

Option 2: Use tagged image
───────────────────────────────────────────────────
1. SSH into CVM
2. View available images:
   docker images | grep ai-chatbot
3. Edit docker-compose.yml to use specific tag:
   image: ccr.../namespace/repo:<commit-sha>
4. Deploy:
   docker-compose pull
   docker-compose up -d --remove-orphans

Option 3: Quick rollback
───────────────────────────────────────────────────
If you have the previous image cached:
1. docker-compose down
2. docker run -d --name ai-chatbot-old \
   <previous-image-id>
```

## Monitoring Points

```
What to Monitor
═══════════════════════════════════════════════════

┌─────────────────────────────────────────────────┐
│  GitHub Actions                                  │
│  • Workflow success/failure                      │
│  • Build time                                    │
│  • Cache hit rate                                │
└─────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────┐
│  CCR                                             │
│  • Image size                                    │
│  • Storage usage                                 │
│  • Pull/push activity                            │
└─────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────┐
│  CVM                                             │
│  • docker ps (container status)                  │
│  • docker stats (resource usage)                 │
│  • /app/deploy.log (deployment logs)             │
│  • docker logs ai-chatbot (app logs)             │
└─────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────┐
│  Application                                     │
│  • HTTP health check (port 3000)                 │
│  • Response time                                 │
│  • Error logs                                    │
└─────────────────────────────────────────────────┘
```

## Time Estimates

```
Typical Workflow Duration
═══════════════════════════════════════════════════

Checkout & Setup:        ~30 seconds
Docker Build:            ~3-5 minutes
Push to CCR:             ~1-2 minutes
SSH to CVM:              ~5 seconds
Pull & Deploy:           ~1-2 minutes
────────────────────────────────────
Total:                   ~5-10 minutes

First run (no cache):    ~10-15 minutes
Subsequent runs:         ~5-8 minutes
```

## Optimization Tips

```
Speed Up Deployments
═══════════════════════════════════════════════════

✓ Use GitHub Actions cache for Docker layers
✓ Use Docker Hub mirror in China regions
✓ Enable buildx with max cache mode
✓ Keep dependencies stable (fewer reinstalls)
✓ Use .dockerignore to exclude unnecessary files
✓ Multi-stage build (smaller final image)
✓ Layer ordering (most stable layers first)
```

---

For more details, see:
- [CCR Setup Guide](CCR_SETUP_GUIDE.md)
- [Deployment Documentation](DEPLOYMENT.md)
- [Setup Instructions](SETUP_INSTRUCTIONS.md)
