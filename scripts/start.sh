#!/bin/bash

# Extract connection details from POSTGRES_URL if not set individually
if [ -z "$POSTGRES_HOST" ]; then
  # Extract host from POSTGRES_URL (format: postgresql://user:password@host:port/db)
  POSTGRES_HOST=$(echo $POSTGRES_URL | sed -n 's/.*@\([^:]*\):.*/\1/p')
fi

if [ -z "$POSTGRES_PORT" ]; then
  POSTGRES_PORT=$(echo $POSTGRES_URL | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
fi

if [ -z "$POSTGRES_USER" ]; then
  POSTGRES_USER=$(echo $POSTGRES_URL | sed -n 's/.*:\/\/\([^:]*\):.*/\1/p')
fi

if [ -z "$POSTGRES_DB" ]; then
  POSTGRES_DB=$(echo $POSTGRES_URL | sed -n 's/.*\/\([^?]*\).*/\1/p')
fi

echo "Database connection info:"
echo "  Host: $POSTGRES_HOST"
echo "  Port: $POSTGRES_PORT"
echo "  User: $POSTGRES_USER"
echo "  Database: $POSTGRES_DB"

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
until pg_isready -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB"; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 2
done

echo "✅ PostgreSQL is ready!"

# Run database migrations
echo "⏳ Running database migrations..."
pnpm db:migrate

if [ $? -eq 0 ]; then
  echo "✅ Migrations completed successfully!"
else
  echo "❌ Migration failed!"
  exit 1
fi

# Start the application
echo "🚀 Starting the application..."
exec "$@"