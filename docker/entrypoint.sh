#!/bin/bash
# Au premier démarrage le volume /uploads est vide ; on y copie les images de démo depuis l'image.
if [ ! -f /var/www/html/uploads/.initialized ]; then
    cp -r /var/www/html/uploads_seed/. /var/www/html/uploads/ 2>/dev/null || true
    touch /var/www/html/uploads/.initialized
    chown -R www-data:www-data /var/www/html/uploads
fi

exec apache2-foreground
