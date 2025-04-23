ARG PHP_VERSION
FROM php:${PHP_VERSION}-fpm-alpine

ARG TARGETARCH
ENV TARGETARCH=${TARGETARCH}

# Display architecture for debugging
RUN echo "Target Arch: $TARGETARCH"

# Add laravel user/group
RUN addgroup -g 1000 laravel && adduser -G laravel -g laravel -s /bin/sh -D laravel

# Set working directory
RUN mkdir -p /var/www/html

# Upgrade apk packages
RUN apk upgrade --update

# Install build dependencies
RUN apk --no-cache --virtual .build-deps add \
    ${PHPIZE_DEPS} autoconf g++ gcc make libc-dev musl-dev \
    freetype-dev libjpeg-turbo-dev libpng-dev libzip-dev \
    imap-dev openssl-dev bzip2-dev libwebp-dev icu-dev \
    libxml2-dev tidyhtml-dev libxslt-dev zlib-dev \
    oniguruma-dev libevent-dev gmp-dev sqlite-dev \
    re2c libtool imagemagick-dev unixodbc-dev librdkafka-dev

# Install runtime dependencies
RUN apk add --no-cache \
    freetds unixodbc sqlite libldap imagemagick bash curl git

# Install PECL: redis
RUN pecl install redis \
    && docker-php-ext-enable redis

# Install PECL: sqlsrv & pdo_sqlsrv
RUN pecl install sqlsrv \
    && docker-php-ext-enable --ini-name 30-sqlsrv.ini sqlsrv

RUN pecl install pdo_sqlsrv \
    && docker-php-ext-enable --ini-name 35-pdo_sqlsrv.ini pdo_sqlsrv

# Install PECL: rdkafka
RUN pecl install rdkafka \
    && docker-php-ext-enable rdkafka

# Configure and install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-configure ldap

RUN docker-php-ext-install \
    pdo pdo_mysql bcmath bz2 dba gd gmp imap intl ldap \
    opcache pcntl pspell snmp soap tidy xsl zip exif

# Install imagick for supported PHP versions
RUN case "$PHP_VERSION" in \
    7.*|8.*) \
        pecl install imagick && docker-php-ext-enable imagick ;; \
    *) \
        echo "Unsupported PHP version for imagick: $PHP_VERSION" && exit 1 ;; \
    esac

# Clean up build dependencies and apk cache
RUN apk del .build-deps \
    && rm -rf /var/cache/apk/*

# Set up PHP config
ADD ./php/www.conf /usr/local/etc/php-fpm.d/www.conf
ADD ./php/php.ini /usr/local/etc/php/php.ini
ADD ./php/ldap.conf /etc/openldap/ldap.conf
ADD ./php/crontab /etc/crontabs/root

# Install Composer globally
RUN curl -sS https://getcomposer.org/installer | php \
    && mv composer.phar /usr/local/bin/composer

# Set ownership of web root
RUN chown -R laravel:laravel /var/www/html
