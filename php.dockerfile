ARG PHP_VERSION
FROM php:${PHP_VERSION}-fpm-alpine

ARG TARGETARCH
ENV TARGETARCH=${TARGETARCH}

RUN echo "Target Arch: $TARGETARCH"

RUN addgroup -g 1000 laravel && adduser -G laravel -g laravel -s /bin/sh -D laravel

RUN mkdir -p /var/www/html

RUN apk upgrade --update

# Dependencies to compile PHP extensions
RUN apk --no-cache --virtual .build-deps add \
    ${PHPIZE_DEPS} autoconf g++ gcc make libc-dev musl-dev \
    freetype-dev libjpeg-turbo-dev libpng-dev libzip-dev \
    imap-dev openssl-dev bzip2-dev libwebp-dev icu-dev \
    libxml2-dev tidyhtml-dev libxslt-dev zlib-dev \
    oniguruma-dev libevent-dev gmp-dev sqlite-dev \
    re2c libtool imagemagick-dev

# Runtime packages
RUN apk add --no-cache \
    freetds unixodbc sqlite libldap librdkafka imagemagick \
    bash curl git

# Install PECL extensions
RUN pecl install redis sqlsrv pdo_sqlsrv rdkafka \
    && docker-php-ext-enable redis sqlsrv pdo_sqlsrv rdkafka

# GD, LDAP, and other PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-configure ldap \
    && docker-php-ext-install \
        pdo pdo_mysql bcmath bz2 dba gd gmp imap intl ldap \
        opcache pcntl pspell snmp soap tidy xsl zip exif

# Install imagick via PECL for supported PHP versions
RUN case "$PHP_VERSION" in \
    7.*|8.*) \
        pecl install imagick && docker-php-ext-enable imagick \
        ;; \
    *) \
        echo "Unsupported PHP version for imagick: $PHP_VERSION" && exit 1 \
        ;; \
    esac

# Clean up build dependencies
RUN apk del .build-deps \
    && rm -rf /var/cache/apk/*

# Set up PHP config files
ADD ./php/www.conf /usr/local/etc/php-fpm.d/www.conf
ADD ./php/php.ini /usr/local/etc/php/php.ini
ADD ./php/ldap.conf /etc/openldap/ldap.conf
ADD ./php/crontab /etc/crontabs/root

# Install Composer globally
RUN curl -sS https://getcomposer.org/installer | php \
    && mv composer.phar /usr/local/bin/composer

RUN chown -R laravel:laravel /var/www/html
