FROM php:8.2-apache

# Extensions PDO pour MySQL et PostgreSQL
RUN apt-get update && apt-get install -y libpq-dev \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql \
    && rm -rf /var/lib/apt/lists/*

# Activer mod_rewrite Apache
RUN a2enmod rewrite

# Copier les sources de l'application
COPY php/www/ /var/www/html/

# Sauvegarder les images de démo pour initialisation du volume au premier démarrage
RUN cp -r /var/www/html/uploads /var/www/html/uploads_seed \
    && chown -R www-data:www-data /var/www/html \
    && chmod 755 /var/www/html/uploads

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
