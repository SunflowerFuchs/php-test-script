#!/usr/bin/env bash

NETWORK_NAME="php-test-net"
PHP_VERSION=8.1
PHP_IMAGE_NAME="local/php-test"
PHP_CONTAINER_NAME="php-test-${RANDOM}"
PHP_CONTENT="<?php\n\n"
EDITOR=""
EDITOR_OFFSET=3
WITH_DB=false
DB_IMAGE_NAME="mysql:8"
DB_CONTAINER_NAME="php-test-db-${RANDOM}"
DB_NAME="testdb"
DB_PASSWORD="${RANDOM}${RANDOM}${RANDOM}"

# read all the parameters and adjust the commands as needed
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      echo "php-test - starts a little php test container"
      echo " "
      echo "php-test [options]"
      echo " "
      echo "options:"
      echo "-h, --help            show this help text"
      echo "--db                  also start an additional database instance (mysql)"
      echo "-f, --file            where on the host system to mount the edited file"
      echo "-v, --version         which version of php to use (defaults to 8.1)"
      exit 0
      ;;
    --db)
      WITH_DB=true
      shift
      ;;
    --version)
      if [[ -z "$2" ]]; then
        echo "No version passed with $1"
        exit 1
      fi
      PHP_VERSION="$2"
      shift 2
      ;;
    --file|-f)
      if [[ -z "$2" ]]; then
        echo "No file passed with $1"
        exit 1
      fi
      MOUNTED_FILE="$2"
      shift 2
      ;;
    --editor|-e)
      if [[ -z "$2" ]]; then
        echo "No file passed with $1"
        exit 1
      fi
      EDITOR="$2"
      shift 2
      ;;
    *)
      echo "Unknown option '$1'"
      exit 1
      ;;
  esac
done

# if no file was passed, generate a temporary file to mount
if [[ -z "$MOUNTED_FILE" ]]; then
  MOUNTED_FILE="$(mktemp -ut php-test).php"
else
  [[ -e "$MOUNTED_FILE" ]] || touch "$MOUNTED_FILE"
  MOUNTED_FILE="$(realpath $MOUNTED_FILE)"
fi

# update variables
PHP_IMAGE_NAME="${PHP_IMAGE_NAME}:${PHP_VERSION}"
PHP_CONTENT="${PHP_CONTENT}// Version: ${PHP_VERSION}\n// File on host system: ${MOUNTED_FILE}\n\n"
EDITOR_OFFSET=$(($EDITOR_OFFSET + 3))
if $WITH_DB; then
  PHP_CONTENT="${PHP_CONTENT}\$host = \"${DB_CONTAINER_NAME}\";\n\$username = \"root\";\n\$password = \"${DB_PASSWORD}\";\n\$database = \"${DB_NAME}\";\n\n\$db = new mysqli(\$host, \$username, \$password, \$database);\n\n"
  EDITOR_OFFSET=$(($EDITOR_OFFSET + 7))
fi

# ensure we're in the right directory
cd -- "$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")" &> /dev/null

# build the image if it doesn't exist
docker image inspect $PHP_IMAGE_NAME >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
  echo "Building image..."
  docker build -t $PHP_IMAGE_NAME --build-arg VERSION="${PHP_VERSION}" .
fi

# create the network if it doesn't exist
docker network inspect $NETWORK_NAME >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
  echo "Creating network..."
  docker network create $NETWORK_NAME
fi

# start the container with the editor
if [[ ! -e "$MOUNTED_FILE" ]] || [[ ! -s "$MOUNTED_FILE" ]]; then
  echo -e "$PHP_CONTENT" > "$MOUNTED_FILE"
fi
docker run --rm -tid --name=$PHP_CONTAINER_NAME --network=$NETWORK_NAME -v "$MOUNTED_FILE:/index.php" $PHP_IMAGE_NAME sh -c "micro -clipboard=internal index.php +${EDITOR_OFFSET}"

# start the watch process that executes the script
tmux split-window -d docker exec -ti $PHP_CONTAINER_NAME sh -c 'while inotifywait -qq -e close_write index.php; do sh -c "clear && php index.php"; done'

# start the db container
if $WITH_DB; then
  docker run --rm -tid --name=$DB_CONTAINER_NAME --network=$NETWORK_NAME -e MYSQL_ROOT_PASSWORD="${DB_PASSWORD}" -e MYSQL_DATABASE="${DB_NAME}" $DB_IMAGE_NAME
  tmux split-window -d -h sh -c "docker exec -ti $PHP_CONTAINER_NAME wait-for-it -t 60 ${DB_CONTAINER_NAME}:3306 && docker exec -ti ${DB_CONTAINER_NAME} mysql --user=root --password=${DB_PASSWORD} ${DB_NAME}"
fi

# start the external editor if one was requested
if [[ ! -z "$EDITOR" ]]; then
  $EDITOR "$MOUNTED_FILE"
fi

# attach the container with the editor
docker attach $PHP_CONTAINER_NAME

if $WITH_DB; then
  docker kill $DB_CONTAINER_NAME >/dev/null 2>&1
fi

# and once the container closes, we can just clear all output to reset the terminal
clear && tmux clear-history
