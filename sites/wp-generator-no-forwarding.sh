#!/bin/bash
read -p 'Database name: ' dbname
read -p 'Database username: ' dbuser
read -p 'Database password: ' dbpass
read -p 'domain: ' wpdomain

echo

DIR="./$wpdomain"

mkdir -p $wpdomain

cat <<EOT >> ./$wpdomain/docker-compose.yml
services:
  nginx:
    image: nginx:stable-bullseye
    restart: unless-stopped
    volumes:
      - ./default.conf:/etc/nginx/conf.d/default.conf
      - ./html:/var/www/html
    environment:
      - VIRTUAL_HOST=$wpdomain
      - LETSENCRYPT_HOST=$wpdomain
      - LETSENCRYPT_EMAIL=info@windowschannel.com
    logging:
      driver: "json-file"
      options:
        max-size: "10m"     
        max-file: "3"       
    depends_on:
      - wordpress-$wpdomain
    networks:
      - wordpress-network

  wordpress-$wpdomain:
    image:  wordpress:php8.3-fpm
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
    logging:
      driver: "json-file"
      options:
        max-size: "10m"     
        max-file: "3"  
    networks:
      - wordpress-network
networks:
  wordpress-network:
    external: true
EOT

# create config file nginx
cat <<EOT >> ./$wpdomain/default.conf
server {
    listen 80;
    server_name $wpdomain;
    root /var/www/html;
    index index.php;

    # Encabezados de Seguridad
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy "no-referrer-when-downgrade";

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

    location ~ /\.ht {
        deny all;
    }

    location = /favicon.ico {
        log_not_found off; access_log off;
    }

    location = /robots.txt {
        log_not_found off; access_log off; allow all;
    }

    location ~* \.(css|gif|ico|jpeg|jpg|js|png|svg|woff|woff2|ttf|eot|mp4|webm)$ {
      expires max;
      log_not_found off;
      access_log off;
    }
}
EOT

cat <<EOT >> ./$wpdomain/uploads.ini
file_uploads = On
upload_max_filesize = 10M
post_max_size = 500M
max_execution_time = 600
EOT