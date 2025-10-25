FROM extremeshok/openlitespeed:latest AS BUILD
LABEL mantainer="Adrian Kriel <admin@extremeshok.com>" vendor="eXtremeSHOK.com"
################################################################################
# This is property of eXtremeSHOK.com
# You are free to use, modify and distribute, however you may not remove this notice.
# Copyright (c) Adrian Jon Kriel :: admin@extremeshok.com
################################################################################

USER root

ARG DEBIAN_FRONTEND=noninteractive
ARG PHP_VERSION=74

RUN echo "**** Install packages ****" \
  && apt-install \
  fontconfig \
  mariadb-client \
  msmtp \
  sudo \
  vim-tiny

RUN echo "**** Install PHP${PHP_VERSION} ****" \
  && PACKAGES="lsphp${PHP_VERSION}-apcu \
  lsphp${PHP_VERSION}-common \
  lsphp${PHP_VERSION}-curl \
  lsphp${PHP_VERSION}-dev \
  lsphp${PHP_VERSION}-igbinary \
  lsphp${PHP_VERSION}-imagick \
  lsphp${PHP_VERSION}-imap \
  lsphp${PHP_VERSION}-intl \
  lsphp${PHP_VERSION}-ldap- \
  lsphp${PHP_VERSION}-memcached \
  lsphp${PHP_VERSION}-modules-source- \
  lsphp${PHP_VERSION}-msgpack \
  lsphp${PHP_VERSION}-mysql \
  lsphp${PHP_VERSION}-opcache \
  lsphp${PHP_VERSION}-pear \
  lsphp${PHP_VERSION}-pgsql- \
  lsphp${PHP_VERSION}-pspell- \
  lsphp${PHP_VERSION}-redis \
  lsphp${PHP_VERSION}-snmp- \
  lsphp${PHP_VERSION}-sqlite3 \
  lsphp${PHP_VERSION}-sybase- \
  lsphp${PHP_VERSION}-tidy-" \
  && if [ "${PHP_VERSION}" = "74" ]; then PACKAGES="${PACKAGES} lsphp${PHP_VERSION}-json"; fi \
  && apt-install ${PACKAGES}
## Note: json is built into PHP 8.0+, only PHP 7.4 has a separate json package
## Note: ioncube not available for php7.4+

RUN echo "**** Default to PHP${PHP_VERSION} and create symbolic links ****" \
  && rm -f /usr/bin/php \
  && rm -f /usr/local/lsws/fcgi-bin/lsphp \
  && ln -s /usr/local/lsws/lsphp${PHP_VERSION}/bin/php /usr/bin/php \
  && ln -s /usr/local/lsws/lsphp${PHP_VERSION}/bin/lsphp /usr/local/lsws/fcgi-bin/lsphp

# Determine PHP major.minor version for config paths
RUN echo "**** Determine PHP version string ****" \
  && if [ "${PHP_VERSION}" = "74" ]; then export PHP_VER_STR="7.4"; \
  elif [ "${PHP_VERSION}" = "80" ]; then export PHP_VER_STR="8.0"; \
  elif [ "${PHP_VERSION}" = "81" ]; then export PHP_VER_STR="8.1"; \
  elif [ "${PHP_VERSION}" = "82" ]; then export PHP_VER_STR="8.2"; \
  elif [ "${PHP_VERSION}" = "83" ]; then export PHP_VER_STR="8.3"; \
  else export PHP_VER_STR="7.4"; fi \
  && echo "export PHP_VERSION=${PHP_VERSION}" >> /etc/environment \
  && echo "export PHP_VER_STR=${PHP_VER_STR}" >> /etc/environment

RUN echo "**** Create symbolic links for /etc/php ****" \
  && . /etc/environment \
  && rm -rf /etc/php \
  && mkdir -p /etc/php \
  && rm -rf /usr/local/lsws/lsphp${PHP_VERSION}/etc/php/${PHP_VER_STR} \
  && mkdir -p /usr/local/lsws/lsphp${PHP_VERSION}/etc/php/${PHP_VER_STR} \
  && ln -s /etc/php/litespeed /usr/local/lsws/lsphp${PHP_VERSION}/etc/php/${PHP_VER_STR}/litespeed \
  && ln -s /etc/php/mods-available /usr/local/lsws/lsphp${PHP_VERSION}/etc/php/${PHP_VER_STR}/mods-available

RUN echo "**** Fix permissions ****" \
  && chown -R lsadm:lsadm /usr/local/lsws

RUN echo "**** Create error.log for php ****" \
  && touch /usr/local/lsws/logs/php_error.log \
  && chown nobody:nogroup /usr/local/lsws/logs/php_error.log

COPY rootfs/ /

RUN echo "**** Test PHP has no warnings ****" \
   && . /etc/environment \
   && if /usr/local/lsws/lsphp${PHP_VERSION}/bin/php -v | grep -q -i warning ; then /usr/local/lsws/lsphp${PHP_VERSION}/bin/php -v ; exit 1 ; fi

RUN echo "**** Test PHP has no errors ****" \
   && . /etc/environment \
   && if /usr/local/lsws/lsphp${PHP_VERSION}/bin/php -v | grep -q -i error ; then /usr/local/lsws/lsphp${PHP_VERSION}/bin/php -v ; exit 1 ; fi

RUN echo "*** Backup PHP Configs ***" \
  && . /etc/environment \
  && mkdir -p  /usr/local/lsws/default/php \
  && cp -rf  /usr/local/lsws/lsphp${PHP_VERSION}/etc/php/${PHP_VER_STR}/* /usr/local/lsws/default/php

#When using Composer, disable the warning about running commands as root/super user
ENV COMPOSER_ALLOW_SUPERUSER=1

RUN echo "**** Install Composer ****" \
    && php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php composer-setup.php \
    && mv composer.phar /usr/local/bin/composer \
    && php -r "unlink('composer-setup.php');"

RUN echo "**** Install PHPUnit ****" \
    && wget -q https://phar.phpunit.de/phpunit.phar \
    && mv phpunit.phar /usr/local/bin/phpunit \
    && chmod +x /usr/local/bin/phpunit

RUN echo "**** Install WP-CLI ****" \
    && wget -q https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp-cli \
    && chmod +x /usr/local/bin/wp-cli \
    && mkdir -p /nonexistent/.wp-cli/cache \
    && chown -R nobody:nogroup /nonexistent/.wp-cli

RUN echo "**** Ensure there is no admin password ****" \
  && rm -f /etc/openlitespeed/admin/htpasswd

RUN echo "**** Correct permissions ****" \
  && chmod 0644 /etc/cron.hourly/vhost-autoupdate \
  && chmod 755 /etc/services.d/*/run \
  && chmod 755 /etc/services.d/*/finish \
  && chmod 755 /xshok-*.sh

WORKDIR /var/www/vhosts/localhost/

EXPOSE 80 443 443/udp 7080 8088

# "when the SIGTERM signal is sent, it immediately quits and all established connections are closed"
# "graceful stop is triggered when the SIGUSR1 signal is sent "
STOPSIGNAL SIGUSR1

HEALTHCHECK --interval=5s --timeout=5s CMD [ "301" = "$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:7080/)" ] || exit 1

ENTRYPOINT ["/init"]
