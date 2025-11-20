# PostgreSQL 17 Auto-Init Schema Setup

This document describes the PostgreSQL 17 auto-initialization setup for the AI Chatbot application.

## Overview

The Docker Compose configuration has been updated to use PostgreSQL 17 with automatic schema initialization. This eliminates the need for manual database setup and migrations.

## Changes Made

### 1. PostgreSQL Service Updates
- **Image**: Upgraded from `postgres:15-alpine` to `postgres:17-alpine`
- **Init Script**: Added volume mount for `./scripts/postgres-init.sql:/docker-entrypoint-initdb.d/init.sql`
- **Auto-Init**: PostgreSQL automatically runs the init script on first container start

### 2. Application Service Updates
- **Database URL**: Updated to use container hostname `ai-chatbot-postgres`
- **Health Check**: Maintains dependency on postgres service health
- **Migration Support**: Existing migration script runs after database is ready

### 3. Database Schema
The `scripts/postgres-init.sql` creates all required tables:
- `User` - User accounts with unique username constraint
- `Chat` - Chat sessions with visibility and context
- `Message_v2` - Current message schema with parts and attachments
- `Vote_v2` - Voting system with composite primary key
- `Document` - Document storage with composite primary key
- `Suggestion` - Document suggestions with foreign key relationships
- `Stream` - Stream management for chat sessions

All tables include:
- Proper UUID primary keys with `gen_random_uuid()`
- Foreign key constraints with proper error handling
- Performance indexes for common query patterns
- Correct data types (UUID, TIMESTAMP, TEXT, JSONB, VARCHAR)

## Usage

### Start the Application
```bash
docker compose up -d
```

### What Happens on Startup
1. PostgreSQL 17 container starts
2. Database `ai_chatbot` and user `ai_user` are created automatically
3. Init script runs, creating all tables with proper schema
4. App container waits for PostgreSQL to be healthy
5. App container starts, runs migrations (idempotent), then starts the application

### Database Connection
- **Host**: `ai-chatbot-postgres` (container hostname)
- **Port**: `5432`
- **Database**: `ai_chatbot`
- **User**: `ai_user`
- **Password**: `your_password` (change in docker-compose.yml)

## Benefits

1. **Zero Manual Setup**: Database is ready immediately on container start
2. **Version Controlled**: Schema is version controlled in git
3. **Consistent Environment**: Same schema across development, staging, and production
4. **Fast Startup**: No manual migration steps required
5. **Idempotent**: Safe to run multiple times, migrations handle updates

## Migration Compatibility

The auto-init schema is compatible with existing Drizzle migrations:
- Tables use `IF NOT EXISTS` to prevent conflicts
- Migrations run after init and handle any schema updates
- Both systems can coexist safely

## Security Considerations

- Change `POSTGRES_PASSWORD` in docker-compose.yml for production
- Consider using Docker secrets or environment files for sensitive data
- Database is exposed on port 5432 - consider restricting access in production

## Troubleshooting

### Database Connection Issues
1. Check PostgreSQL container logs: `docker compose logs postgres`
2. Verify database is healthy: `docker compose ps`
3. Test connection: `docker compose exec postgres psql -U ai_user -d ai_chatbot`

### Schema Issues
1. Review init script: `scripts/postgres-init.sql`
2. Check migration logs: `docker compose logs app`
3. Verify table creation: Connect to database and run `\dt`

### Performance Issues
1. Monitor PostgreSQL metrics
2. Check index usage with `EXPLAIN ANALYZE`
3. Consider connection pooling for high traffic