#!/bin/bash

# See [https://github.com/ellakcy/docker-moodle/tree/master]
# Even though some containers may not have some support for a specific db
# We provide a generic entrypoint for better maintainance

# Ping Database function
function pingdb {
    OK=0
    for count in {1..100}; do
      echo "Pinging database attempt ${count} into ${MOODLE_DB_HOST}:${MOODLE_DB_PORT}" 
      if  $(nc -z ${MOODLE_DB_HOST} ${MOODLE_DB_PORT}) ; then
        echo "Can connect into database"
        OK=1
        break
      fi
      sleep 5
    done

    echo "Is ok? "$OK

    if [ $OK -eq 1 ]; then
      echo "DB connected"
    else
      echo >&2 "Can't connect into database"
      exit 1
    fi
}


echo "Moving files into web folder"
rsync -rvad --chown www-data:www-data /usr/src/moodle/* /var/www/html/

echo "Fixing files and permissions"
chown -R www-data:www-data /var/www/html
find /var/www/html -iname "*.php" | xargs chmod 655

echo "placeholder" > /var/moodledata/placeholder
chown -R www-data:www-data /var/moodledata
chmod 777 /var/moodledata

MOODLE_DB_TYPE="pgsql"
HAS_POSTGRES_SUPPORT=$(php -m | grep -i pgsql |wc -w)

echo "Installing moodle with postgres support"

if [ $HAS_POSTGRES_SUPPORT -gt 0 ]; then


  : ${MOODLE_DB_HOST:="moodle_db"}
  : ${MOODLE_DB_PORT:=5432}

    echo "Setting up the database connection info"

  : ${MOODLE_DB_NAME:=${DB_ENV_POSTGRES_DB:-'moodle'}}
  : ${MOODLE_DB_USER:=${DB_ENV_POSTGRES_USER}}
  : ${MOODLE_DB_PASSWORD:=$DB_ENV_POSTGRES_PASSWORD}

  echo >&1 ${MOODLE_DB_HOST}
  echo >&1 ${MOODLE_DB_PORT}
  echo >&1 ${MOODLE_DB_NAME}
  echo >&1 ${MOODLE_DB_USER}
  echo >&1 ${MOODLE_DB_PASSWORD} 

  pingdb

else
  echo >&2 "No database support found"
  exit 1
fi


if [ -z "$MOODLE_DB_PASSWORD" ]; then
  echo >&2 'error: missing required MOODLE_DB_PASSWORD environment variable'
  echo >&2 '  Did you forget to -e MOODLE_DB_PASSWORD=... ?'
  echo >&2
  exit 1
fi

echo "Installing moodle"
MOODLE_DB_TYPE=$MOODLE_DB_TYPE php /var/www/html/admin/cli/install_database.php \
          --adminemail=${MOODLE_ADMIN_EMAIL} \
          --adminuser=${MOODLE_ADMIN} \
          --adminpass=${MOODLE_ADMIN_PASSWORD} \
          --agree-license

MOODLE_DB_TYPE=$MOODLE_DB_TYPE php admin/cli/purge_caches.php

MOODLE_DB_TYPE=$MOODLE_DB_TYPE exec "$@"