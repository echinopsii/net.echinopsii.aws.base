#!/usr/bin/env bash
set -e
set -x

mv /tmp/files/start.sh /

DEP="libpng12-dev libjpeg-dev"
export DEBIAN_FRONTEND=noninteractive

echo "Installing dependencies..."
apt-get update -y && apt-get upgrade -y && apt-get install -y ${DEP}

rm -rf /var/lib/apt/lists/* && docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr \
&& docker-php-ext-install gd mysqli opcache

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
{ \
  echo 'opcache.memory_consumption=128'; \
  echo 'opcache.interned_strings_buffer=8'; \
  echo 'opcache.max_accelerated_files=4000'; \
  echo 'opcache.revalidate_freq=2'; \
  echo 'opcache.fast_shutdown=1'; \
  echo 'opcache.enable_cli=1'; \
} > /usr/local/etc/php/conf.d/opcache-recommended.ini

a2enmod rewrite expires

WORDPRESS_VERSION="4.6.1"
WORDPRESS_SHA1="027e065d30a64720624a7404a1820e6c6fff1202"

curl -o wordpress.tar.gz -fSL "https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz" \
  && echo "$WORDPRESS_SHA1 *wordpress.tar.gz" | sha1sum -c - \
  && tar -xzf wordpress.tar.gz -C /usr/src/ \
  && rm wordpress.tar.gz \
  && chown -R www-data:www-data /usr/src/wordpress

mv /tmp/files/usr/src/wordpress/* /usr/src/wordpress
