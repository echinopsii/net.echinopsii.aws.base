#!/bin/sh
set -e

if [ -f ./wordpress.env ]; then
	. ./wordpress.env
        echo "CREATE DATABASE IF NOT EXISTS DB_NAME;" > wordpress_db_init.sql
	cp wp-config-sample.php wp-config.php
else
	echo >&2 'error: missing wordpress.env file'
        echo >&2
        exit 1
fi

if [ -z "$WORDPRESS_DB_HOST" ]; then
        echo >&2 'error: missing required WORDPRESS_DB_HOST environment variable'
        echo >&2 '  Did you forget to define WORDPRESS_DB_HOST=... in wordpress.env ?'
        echo >&2
        exit 1
fi

if [ -z "$WORDPRESS_DB_PORT" ]; then
        echo >&2 'error: missing required WORDPRESS_DB_PORT environment variable'
        echo >&2 '  Did you forget to define WORDPRESS_DB_PORT=... in wordpress.env ?'
        echo >&2
        exit 1
fi

if [ -z "$WORDPRESS_DB_USER" ]; then
        echo >&2 'error: missing required WORDPRESS_DB_USER environment variable'
        echo >&2 '  Did you forget to define WORDPRESS_DB_USER=... in wordpress.env ?'
        echo >&2
        exit 1
fi

if [ -z "$WORDPRESS_DB_PASSWORD" ]; then
	echo >&2 'error: missing required WORDPRESS_DB_PASSWORD environment variable'
	echo >&2 '  Did you forget to define WORDPRESS_DB_PASSWORD=... in wordpress.env ?'
	echo >&2
	exit 1
fi

if [ -z "$WORDPRESS_DB_NAME" ]; then
        echo >&2 'error: missing required WORDPRESS_DB_NAME environment variable'
        echo >&2 '  Did you forget to define WORDPRESS_DB_NAME=... in wordpress.env ?'
        echo >&2
        exit 1
fi


set_config() {
	key=$1
	value=$2
	sed -i -e "s/define('"$key"',.*);/define('"$key"', '"$value"');/g" ./wp-config.php
}

set_sql_script() {
	key=$1
	value=$2
	sed -i -e "s/"$key"/"$value"/g" ./wordpress_db_init.sql
}

set_config 'DB_HOST' "$WORDPRESS_DB_HOST"
set_config 'DB_USER' "$WORDPRESS_DB_USER"
set_config 'DB_PASSWORD' "$WORDPRESS_DB_PASSWORD"
set_config 'DB_NAME' "$WORDPRESS_DB_NAME"
set_sql_script 'DB_NAME' "$WORDPRESS_DB_NAME"
docker run -it --name mysqlcli -v "$PWD":/tmp -w /tmp mysql sh -c "exec mysql -h $WORDPRESS_DB_HOST -P $WORDPRESS_DB_PORT -u$WORDPRESS_DB_USER -p$WORDPRESS_DB_PASSWORD < wordpress_db_init.sql" 1>/dev/null 2>&1
docker stop mysqlcli 1>/dev/null 2>&1
docker rm mysqlcli 1>/dev/null 2>&1
