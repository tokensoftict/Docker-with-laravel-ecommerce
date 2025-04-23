ARG PHP_VERSION

FROM php:${PHP_VERSION}-fpm-alpine

ARG TARGETARCH

RUN echo $TARGETARCH

RUN addgroup -g 1000 laravel && adduser -G laravel -g laravel -s /bin/sh -D laravel

RUN mkdir -p /var/www/html

RUN apk upgrade --update

# Add packages to the _build_deps_ virtual bundle. These are used only to build
#   the PHP modules and can be deleted later
RUN apk --no-cache --virtual _build_deps_ add \
    ${PHPIZE_DEPS} autoconf file g++ gcc make binutils libc-dev musl-dev libstdc++ libgcc gmp-dev \
    freetype-dev libjpeg-turbo-dev libmcrypt-dev libpng-dev imap-dev openssl-dev libzip-dev curl-dev \
    pcre-dev bzip2-dev libwebp-dev icu-dev ldb-dev openldap-dev \
    oniguruma-dev freetds-dev unixodbc-dev aspell-dev libedit-dev net-snmp-dev libxml2-dev \
    sqlite-dev tidyhtml-dev libxslt-dev zlib-dev libidn2-dev libevent-dev libidn-dev imagemagick-dev \
    libatomic re2c mpc1 gmp libgomp coreutils libltdl gnupg libtool mysql-client

# Add packages that need to be kept on the system
RUN apk add freetds unixodbc sqlite libldap php-ldap

RUN pecl install redis sqlsrv pdo_sqlsrv \
	&& docker-php-ext-enable redis \
	&& docker-php-ext-enable --ini-name 30-sqlsrv.ini sqlsrv \
	&& docker-php-ext-enable --ini-name 35-pdo_sqlsrv.ini pdo_sqlsrv

RUN docker-php-ext-configure gd --with-jpeg --with-webp --with-freetype \
    && docker-php-ext-configure ldap

RUN docker-php-ext-install \
    pdo pdo_mysql bcmath bz2 dba gd gmp imap intl ldap \
	opcache pcntl pspell snmp soap tidy xsl zip

RUN docker-php-ext-install exif \
    && docker-php-ext-enable exif

RUN apk add --no-cache librdkafka-dev \
    && pecl install rdkafka \
    && docker-php-ext-enable rdkafka

RUN apt-get update && \
    apt-get install -y libmagickwand-dev --no-install-recommends && \
    pecl install imagick && \
    docker-php-ext-enable imagick && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN if [ "${PHP_VERSION}" = "7.4" ]; then \
        docker-php-ext-enable xmlrpc; \
        apk add --no-cache imagemagick; \
        pecl install -o -f imagick; \
        docker-php-ext-enable imagick; \
    elif [ "${PHP_VERSION}" = "8.0" ]; then \
        apk add --no-cache imagemagick; \
        pecl install -o -f imagick; \
        docker-php-ext-enable imagick; \
    elif [ "${PHP_VERSION}" = "8.1" ] || \
         [ "${PHP_VERSION}" = "8.2" ] || \
         [ "${PHP_VERSION}" = "8.3" ] || \
         [ "${PHP_VERSION}" = "8.4" ]; then \
        apk add --no-cache imagemagick; \
        pecl install -o -f imagick; \
        docker-php-ext-enable imagick; \
    else \
        echo "Unsupported PHP version: ${PHP_VERSION}"; \
        exit 1; \
    fi

# packages not working - cgi cli common dev interbase phpdbg sybase imagick memcached enchant

RUN rm -rf /var/cache/apk/*

# RUN apk del _build_deps_

ADD ./php/www.conf /usr/local/etc/php-fpm.d/www.conf
ADD ./php/php.ini /usr/local/etc/php/php.ini
ADD ./php/ldap.conf /etc/openldap/ldap.conf
ADD ./php/crontab /etc/crontabs/root

# INSTALL COMPOSER
RUN curl -s https://getcomposer.org/installer | php \
	&& mv composer.phar /bin/composer.phar \
	&& alias composer='php /bin/composer.phar'

RUN chown laravel:laravel /var/www/html

# INSTALL libreoffice and fonts
#RUN apk update && apk add libreoffice
#RUN apk add --no-cache msttcorefonts-installer fontconfig
#RUN update-ms-fonts

# Google fonts
#RUN wget https://github.com/google/fonts/archive/main.tar.gz -O gf.tar.gz --no-check-certificate
#RUN tar -xf gf.tar.gz
#RUN mkdir -p /usr/share/fonts/truetype/google-fonts
#RUN find $PWD/fonts-main/ -name "*.ttf" -exec install -m644 {} /usr/share/fonts/truetype/google-fonts/ \; || return 1
#RUN rm -f gf.tar.gz
#RUN fc-cache -f && rm -rf /var/cache/*


#RUN apk add samba