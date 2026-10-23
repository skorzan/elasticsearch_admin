ARG ALPINE_VERSION=3.24
FROM alpine:${ALPINE_VERSION}
# Security Patches & Hardening:
# - CVE-2026-109618 & CVE-2026-109619 (PHP2Shell): Critical RCE via OOM memory corruption & use-after-free fixed in PHP 8.4.27+
# - CVE-2026-109449: Unbounded nesting DoS in expression parser fixed in Symfony 7.4.21+

LABEL Description="Lightweight container with Nginx and PHP 8.4.27 (patches for CVE-2026-109618, CVE-2026-109619, CVE-2026-109449)"
LABEL org.opencontainers.image.title="Elasticsearch Admin"
LABEL org.opencontainers.image.description="Elasticsearch Admin with Nginx and hardened PHP 8.4.27 runtime"
LABEL org.opencontainers.image.source="https://github.com/skorzan/elasticsearch_admin"
LABEL org.opencontainers.image.url="https://github.com/skorzan/elasticsearch_admin"
LABEL org.opencontainers.image.vendor="skorzan"
LABEL security.patches.php="CVE-2026-109618, CVE-2026-109619 (PHP 8.4.27)"
LABEL security.patches.symfony="CVE-2026-109449 (Symfony 7.4.21)"
LABEL security.cve.fixed="CVE-2026-109618, CVE-2026-109619, CVE-2026-109449"

ENV APP_ENV=prod
ENV INSTALLATION_TYPE=docker
ENV ELASTICSEARCH_URL=$ELASTICSEARCH_URL
ENV ELASTICSEARCH_USERNAME=$ELASTICSEARCH_USERNAME
ENV ELASTICSEARCH_PASSWORD=$ELASTICSEARCH_PASSWORD
ENV ELASTICSEARCH_API_KEY=$ELASTICSEARCH_API_KEY
ENV SSL_VERIFY_PEER=$SSL_VERIFY_PEER
ENV SSL_VERIFY_HOST=$SSL_VERIFY_HOST

ENV SECRET_REGISTER=$SECRET_REGISTER

# Install packages and remove default server definition
RUN apk --no-cache upgrade && \
    apk --no-cache add 'php84>=8.4.27' php84-fpm php84-opcache php84-json php84-openssl php84-curl php84-zlib php84-fileinfo \
    php84-xml php84-simplexml php84-phar php84-intl php84-dom php84-xmlreader php84-ctype php84-session php84-gd \
    php84-tokenizer php84-pdo php84-pdo_mysql php84-pdo_pgsql php84-iconv php84-zip php84-gmp php84-mbstring php84-xmlwriter \
    nginx supervisor curl

# Create symlink so programs depending on `php` still function
RUN ln -s /usr/bin/php84 /usr/bin/php

# Configure nginx
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/privkey.pem /etc/nginx/privkey.pem
COPY docker/fullchain.pem /etc/nginx/fullchain.pem
RUN rm -f /etc/nginx/conf.d/default.conf

# Configure PHP-FPM
COPY docker/fpm-pool.conf /etc/php84/php-fpm.d/www.conf
COPY docker/php.ini /etc/php84/conf.d/custom.ini

# Configure supervisord
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Create folders
RUN mkdir -p /var/www/html && mkdir -p /.composer

# Make sure files/folders needed by the processes are accessable when they run under the nobody user
RUN chown -R nobody:nobody /var/www/html && \
  chown -R nobody:nobody /.composer && \
  chown -R nobody:nobody /etc/nginx && \
  chown -R nobody:nobody /run && \
  chown -R nobody:nobody /var/lib/nginx && \
  chown -R nobody:nobody /var/log/nginx

# Switch to use a non-root user from here on
USER nobody

# Add application
WORKDIR /var/www/html
COPY --chown=nobody . /var/www/html/

# Install composer from the official image
COPY --from=composer /usr/bin/composer /usr/bin/composer

# Run composer install to install the dependencies
RUN composer install --optimize-autoloader --no-interaction --no-progress --no-dev

RUN bin/console asset-map:compile

COPY --chown=nobody .env.dist .env

# Expose the port nginx is reachable on
EXPOSE 8080

# Let supervisord start nginx & php-fpm
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping
