#!/bin/bash
# Point d'entrée du conteneur PHP.
# Au premier démarrage, le volume /uploads est vide.
# On copie les images de démonstration depuis l'image Docker vers le volume.
if [ ! -f /var/www/html/uploads/.initialized ]; then
    cp -r /var/www/html/uploads_seed/. /var/www/html/uploads/ 2>/dev/null || true
    touch /var/www/html/uploads/.initialized
    chown -R www-data:www-data /var/www/html/uploads
fi

# Démarrage d'Apache en avant-plan (obligatoire pour Docker)
exec apache2-foreground
