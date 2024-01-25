ARG VERSION="8.1"
FROM php:$VERSION-cli

# run updates & install dependencies
RUN apt-get update \
 && apt-get upgrade --yes \
 && apt-get install --yes micro inotify-tools wait-for-it

# install additional extensions
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions mysqli
