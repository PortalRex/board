FROM php:8.4-apache
COPY --from=composer /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

ARG SERVER_NAME=board.portal2.local
ARG APT_PACKAGES
ARG DEBIAN_FRONTEND=noninteractive
ARG UID=1000
ARG GID=1000

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y ${APT_PACKAGES} curl unzip cron
# curl, mbstring and SimpleXML are built into the official PHP images; only mysqli needs adding.
RUN docker-php-ext-install mysqli
# The official image has no php.ini (PHP's built-in defaults show errors to visitors, don't buffer output
# and allow short open tags). Use PHP's recommended production settings, like Ubuntu's package did,
# also without the X-Powered-By header, as Ubuntu had it.
RUN cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
    && sed -i 's/^expose_php = On/expose_php = Off/' "$PHP_INI_DIR/php.ini"
RUN a2enmod rewrite expires headers ssl remoteip
RUN a2dissite 000-default.conf
RUN groupmod -g ${GID} www-data
RUN usermod -u ${UID} -g ${GID} www-data

COPY . .

RUN COMPOSER_ALLOW_SUPERUSER=1 composer install
RUN mkdir -p cache demos sessions /etc/apache2/ssl
RUN chown -R www-data:www-data .

RUN ln -s /etc/apache2/sites-available/${SERVER_NAME}.conf /etc/apache2/sites-enabled/${SERVER_NAME}.conf
RUN echo 'ServerName localhost' >> /etc/apache2/apache2.conf

RUN echo '*/1 * * * * www-data /usr/local/bin/php -f /var/www/html/util/refreshCache.php > /dev/null 2>&1' > /etc/cron.d/board
#RUN echo '0 0 */4 * * www-data php -f /var/www/html/util/fetchImportantProfileData.php > /dev/null 2>&1' >> /etc/cron.d/board

EXPOSE 80 443

CMD service cron start && apachectl -D FOREGROUND
