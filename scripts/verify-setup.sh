#!/bin/bash

echo "🔍 Verifying Docker Compose Setup..."

# Check if docker compose is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed or not in PATH"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose is not available"
    exit 1
fi

echo "✅ Docker and Docker Compose are available"

# Validate docker-compose.yml
echo "🔍 Validating docker-compose.yml..."
if docker compose config > /dev/null 2>&1; then
    echo "✅ docker-compose.yml is valid"
else
    echo "❌ docker-compose.yml has errors"
    docker compose config
    exit 1
fi

# Check if required files exist
echo "🔍 Checking required files..."

required_files=(
    "docker-compose.yml"
    "Dockerfile"
    "scripts/start.sh"
    ".env.production"
    "lib/db/migrate.ts"
    "lib/db/schema.ts"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file exists"
    else
        echo "❌ $file is missing"
        exit 1
    fi
done

# Check if start.sh is executable
if [ -x "scripts/start.sh" ]; then
    echo "✅ scripts/start.sh is executable"
else
    echo "❌ scripts/start.sh is not executable"
    exit 1
fi

# Check if migrations directory exists and has files
if [ -d "lib/db/migrations" ] && [ "$(ls -A lib/db/migrations)" ]; then
    echo "✅ Migrations directory exists with migration files"
    migration_count=$(find lib/db/migrations -name "*.sql" | wc -l)
    echo "   Found $migration_count migration files"
else
    echo "❌ Migrations directory is empty or missing"
    exit 1
fi

# Check environment variables in .env.production
echo "🔍 Checking .env.production variables..."
required_vars=(
    "AUTH_SECRET"
    "NEXTAUTH_URL"
)

for var in "${required_vars[@]}"; do
    if grep -q "^$var=" .env.production; then
        echo "✅ $var is set"
    else
        echo "⚠️  $var is not set (may need to be configured)"
    fi
done

echo ""
echo "🎉 Docker Compose setup verification completed!"
echo ""
echo "📋 Next steps:"
echo "   1. Update .env.production with your actual values"
echo "   2. Run: docker compose up --build"
echo "   3. Check logs: docker compose logs -f"
echo ""
echo "📚 For detailed instructions, see: DOCKER_SETUP.md"