#!/bin/sh
set -e

# Generate unique ephemeral self-signed SSL cert if custom certs are not mounted
if [ ! -s /etc/nginx/ssl/privkey.pem ] || [ ! -s /etc/nginx/ssl/fullchain.pem ]; then
    mkdir -p /etc/nginx/ssl 2>/dev/null || true
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/privkey.pem \
        -out /etc/nginx/ssl/fullchain.pem \
        -subj "/CN=localhost" 2>/dev/null
    chmod 600 /etc/nginx/ssl/privkey.pem 2>/dev/null || true
fi

exec "$@"
