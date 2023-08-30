#!/bin/bash

read -p 'Database name: ' dbname
read -p 'Database username: ' dbuser
read -p 'Database password: ' dbpass
read -p 'domain: ' wpdomain

echo

DIR="./$wpdomain"

mkdir -p $wpdomain
mkdir -p $wpdomain/nginx/conf.d

cat <<EOT >> ./$wpdomain/docker-compose.yml
version: '3.8'

services:
    nginx:
        image: nginx:1.25-alpine
        restart: unless-stopped
        volumes:
            - ./nginx/conf.d:/etc/nginx/conf.d
            - ./html:/var/www/html
        environment:
            - VIRTUAL_HOST=$wpdomain
            - LETSENCRYPT_HOST=$wpdomain
            - LETSENCRYPT_EMAIL=info@windowschannel.com
        expose:
            - "80"
        links:
            - wp

    wp: 
        image: wordpress:php8.2
        restart: unless-stopped
        volumes:      
            - ./html:/var/www/html
            - ./uploads.ini:/usr/local/etc/php/conf.d/uploads.ini
        environment:
            - WORDPRESS_DB_HOST=db  
            - WORDPRESS_DB_NAME=$dbname
            - WORDPRESS_DB_USER=$dbuser
            - WORDPRESS_DB_PASSWORD=$dbpass

networks:
  default:
    external:
      name: wordpress-sites
EOT

# create config file nginx
cat <<EOT >> ./$wpdomain/nginx/conf.d/default.conf
server {  
	listen 80;  
	listen [::]:80;  
	access_log off;  
	root /var/www/html;  
	index index.php index.html;  
	server_name $wpdomain
	server_tokens off;  

	location / {    
		try_files $uri $uri/ /index.php?$args;  
		location ~ \.php$ {    
			fastcgi_split_path_info ^(.+\.php)(/.+)$;    
			fastcgi_pass $wpdomain:9000;    
			fastcgi_index index.php;    
			include fastcgi_params;    
			fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;    
			fastcgi_param SCRIPT_NAME $fastcgi_script_name;  
			}
	}
}
EOT