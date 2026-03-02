#!/bin/bash
echo "php version:" 
php -v 

# sleep
echo "sleep 10s"
sleep 10s

# run migrations
echo "RUN :php artisan migrate "
php artisan migrate

echo "RUN php artisna db seed"
php artisan db:seed

# link starage
echo "php artisan storage:unlink"
echo "php artisan storage:link"
php artisan storage:link

# Start PHP-FPM
echo "Start :PHP-FPM "
exec php-fpm
