#!/bin/sh
set -e

echo "🚀 Laravel container starting..."

# Ensure required runtime directories exist
mkdir -p storage/framework/cache
mkdir -p storage/framework/sessions
mkdir -p storage/framework/views
mkdir -p storage/logs
mkdir -p bootstrap/cache
mkdir -p database

# Fix permissions
chown -R www-data:www-data storage bootstrap/cache database
chmod -R 775 storage bootstrap/cache database

# If using SQLite and file doesn't exist → create it
if [ "$DB_CONNECTION" = "sqlite" ]; then
  if [ ! -f "$DB_DATABASE" ]; then
    echo "📦 Creating SQLite database file..."
    touch "$DB_DATABASE"
    chown www-data:www-data "$DB_DATABASE"
  fi
fi

echo "⏳ Running migrations..."
php artisan migrate --force

echo "⚡ Caching config..."
php artisan config:clear
php artisan config:cache
php artisan route:cache || true

echo "✅ Starting PHP-FPM..."
exec php-fpm