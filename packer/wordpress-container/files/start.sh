#!/usr/bin/env bash
set -e
set -x

cd /var/www/html

if ! [ -e index.php -a -e wp-includes/version.php ]; then
  echo >&2 "WordPress not found in $(pwd) - copying now..."
  if [ "$(ls -A)" ]; then
     echo >&2 "WARNING: $(pwd) is not empty - press Ctrl+C now if this is an error!"
     ( set -x; ls -A; sleep 10 )
  fi
  tar cf - --one-file-system -C /usr/src/wordpress . | tar xf -
  echo >&2 "Complete! WordPress has been successfully copied to $(pwd)"
  if [ ! -e .htaccess ]; then
    echo "# BEGIN WordPress" > .htaccess
    echo "<IfModule mod_rewrite.c>" >> .htaccess
    echo "RewriteEngine On" >> .htaccess
    echo "RewriteBase /" >> .htaccess
    echo "RewriteRule ^index\.php$ - [L]"  >> .htaccess
    echo "RewriteCond %{REQUEST_FILENAME} !-f"  >> .htaccess
    echo "RewriteCond %{REQUEST_FILENAME} !-d"  >> .htaccess 
    echo "RewriteRule . /index.php [L]"  >> .htaccess
    echo "</IfModule>"  >> .htaccess
    echo "# END WordPress"  >> .htaccess
    chown www-data:www-data .htaccess
  fi
  cp wp-config-sample.php wp-config.php
fi

exec apache2-foreground
