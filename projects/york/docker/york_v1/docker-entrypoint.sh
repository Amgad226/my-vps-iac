#!/bin/bash
echo "php version:" 
php -v 

# sleep
echo "sleep 15s"
sleep 15s

# run migrations
echo "RUN :php artisan migrate --seed "
php artisan migrate --seed

# link starage
echo "php artisan storage:unlink"
echo "php artisan storage:link"
php artisan storage:link

# Start PHP-FPM
echo "Start :PHP-FPM "
exec php-fpm
