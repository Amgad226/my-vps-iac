#!/bin/sh
set -e

echo "🚀 Starting Laravel container..."

# Ensure storage and database directories exist
mkdir -p /var/www/html/storage
mkdir -p /var/www/html/database

DB_FILE="/var/www/html/database/database.sqlite"

if [ ! -f "$DB_FILE" ]; then
    echo "📦 Creating SQLite database at $DB_FILE..."
    touch "$DB_FILE"
fi

# Fix permissions
echo "🔐 Fixing permissions..."
chown -R www-data:www-data /var/www/html/storage
chown -R www-data:www-data /var/www/html/database
chmod -R 775 /var/www/html/storage
chmod -R 775 /var/www/html/database
chmod 664 /var/www/html/database/database.sqlite

# Run migrations
echo "🗄 Running migrations..."
php artisan migrate --force

# Cache config and routes
php artisan config:cache
php artisan route:cache || true

echo "✅ Laravel ready!"

# Start PHP-FPM
exec php-fpm