#!/bin/bash
read -p 'Database name: ' dbname
read -p 'Database username: ' dbuser
read -p 'Database password: ' dbpass
read -p 'domain: ' wpdomain

echo

DIR="./$wpdomain"

mkdir -p $wpdomain
mkdir -p $wpdomain/nginx/conf.d
mkdir -p $wpdomain/html

cat <<EOT >> ./$wpdomain/docker-compose.yml
services:
  nginx:
    image: nginx:stable-alpine3.20
    restart: unless-stopped
    volumes:
      - ./nginx/conf.d/default.conf:/etc/nginx/conf.d/default.conf
      - ./html:/var/www/html
    environment:
      VIRTUAL_HOST: $wpdomain
      LETSENCRYPT_HOST: $wpdomain
      LETSENCRYPT_EMAIL: info@windowschannel.com
    depends_on:
      - wordpress-$wpdomain
    networks:
      - wordpress-network

  wordpress-$wpdomain:
    image: wordpress:php8.3-fpm-alpine
    restart: unless-stopped
    volumes:
      - ./html:/var/www/html
      - ./uploads.ini:/usr/local/etc/php/conf.d/uploads.ini
    environment:
      - WORDPRESS_DB_HOST=db  
      - WORDPRESS_DB_NAME=$dbname
      - WORDPRESS_DB_USER=$dbuser
      - WORDPRESS_DB_PASSWORD=$dbpass
      - VIRTUAL_HOST=$wpdomain
    networks:
      - wordpress-network
networks:
  wordpress-network:
    external: true
EOT

# create config file nginx
cat <<EOT >> ./$wpdomain/nginx/conf.d/default.conf
server {
    listen 80;
    server_name $wpdomain;
    root /var/www/html;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    rewrite /wp-admin\$ \$scheme://\$host\$uri/ permanent;

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass wordpress-$wpdomain:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
    }
}
EOT