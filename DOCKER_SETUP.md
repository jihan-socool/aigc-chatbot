# Docker Compose Setup with PostgreSQL

This setup includes a PostgreSQL service and automatic database initialization for the AI Chatbot application.

## Services

### PostgreSQL Service
- **Image**: `postgres:15-alpine`
- **Container Name**: `ai-chatbot-postgres`
- **Database**: `ai_chatbot`
- **User**: `ai_user`
- **Password**: `your_password` (change this for production)
- **Port**: `5432` (exposed for debugging)
- **Health Check**: Uses `pg_isready` to ensure database is ready
- **Persistence**: Data is stored in `db_data` named volume

### Application Service
- **Container Name**: `ai-chatbot`
- **Dependencies**: Waits for PostgreSQL to be healthy before starting
- **Database URL**: `postgresql://ai_user:your_password@postgres:5432/ai_chatbot`
- **Auto-migration**: Runs database migrations automatically on startup
- **Port**: `3000`

## Usage

### Quick Start
```bash
# Start all services
docker compose up -d

# View logs
docker compose logs -f

# Stop all services
docker compose down
```

### Development
```bash
# Build and start
docker compose up --build

# Rebuild only the app
docker compose up --build app

# Run migrations manually (if needed)
docker compose exec app pnpm db:migrate
```

### Database Management
```bash
# Connect to PostgreSQL
docker compose exec postgres psql -U ai_user -d ai_chatbot

# View database logs
docker compose logs postgres

# Reset database (WARNING: deletes all data)
docker compose down -v
docker compose up -d
```

## Environment Variables

### Required in `.env.production`:
- `AUTH_SECRET`: NextAuth secret key
- `AI_GATEWAY_API_KEY`: Vercel AI Gateway API key
- `BLOB_READ_WRITE_TOKEN`: Vercel Blob storage token
- `NEXTAUTH_URL`: Application URL
- `REDIS_URL`: Redis connection URL (optional)

### Database Configuration:
- `POSTGRES_URL`: Automatically set to `postgresql://ai_user:your_password@postgres:5432/ai_chatbot`

## Database Initialization

The application automatically initializes the database on first startup:

1. **Health Check**: Waits for PostgreSQL to be ready
2. **Migration**: Runs all pending migrations using `pnpm db:migrate`
3. **Tables Created**: 
   - User
   - Chat
   - Message_v2
   - Vote_v2
   - Document
   - Suggestion
   - Stream

## Security Notes

⚠️ **For Production**:
1. Change the default PostgreSQL password
2. Use proper secrets management
3. Remove the PostgreSQL port exposure (5432:5432) if not needed
4. Update the AUTH_SECRET with a secure random value
5. Configure proper SSL/TLS for database connections

## Troubleshooting

### Database Connection Issues
```bash
# Check PostgreSQL health
docker compose exec postgres pg_isready -U ai_user -d ai_chatbot

# Check application logs for database errors
docker compose logs app
```

### Migration Issues
```bash
# Check migration status
docker compose exec app pnpm db:check

# Force re-run migrations (if needed)
docker compose exec app pnpm db:up
```

### Reset Everything
```bash
# Stop and remove all containers, networks, and volumes
docker compose down -v --remove-orphans

# Start fresh
docker compose up --build
```