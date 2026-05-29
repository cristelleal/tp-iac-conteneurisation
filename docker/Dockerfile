FROM php:8.2-apache

# Extensions PDO pour MySQL et PostgreSQL
RUN apt-get update && apt-get install -y libpq-dev \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql \
    && rm -rf /var/lib/apt/lists/*

RUN a2enmod rewrite

COPY php/www/ /var/www/html/

# Seed des images de démo pour l'initialisation du volume (voir entrypoint.sh)
RUN cp -r /var/www/html/uploads /var/www/html/uploads_seed \
    && chown -R www-data:www-data /var/www/html \
    && chmod 755 /var/www/html/uploads

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
