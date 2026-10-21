FROM docker.io/library/php:8.5-fpm-alpine

# Set Piwigo version (PHP_VERSION is provided by the base image)
ARG PIWIGO_VERSION="16.4.0"
ARG BUILD_VERSION=${PIWIGO_VERSION}c
ARG PHP_EXTENSION_INSTALLER_VERSION="2.12.0"

# Default timezone, override with the TZ environment variable
ENV TZ=UTC

# Install dependencies
RUN apk add --update --no-cache \
	# s6-overlay and Nginx
	s6-overlay nginx \
	# Extra dependencies
	acl curl exiftool findutils icu-data-full postfix tzdata  \
	# Imagemagick and media editing tools
	ffmpeg mediainfo ghostscript libheif-plugins-all \
	imagemagick imagemagick-heic imagemagick-jpeg imagemagick-jxl imagemagick-pango \
	imagemagick-pdf imagemagick-raw imagemagick-svg imagemagick-tiff imagemagick-webp

# Install PHP extensions not already built into the base image
ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/download/${PHP_EXTENSION_INSTALLER_VERSION}/install-php-extensions /usr/local/bin/
RUN install-php-extensions \
	bcmath calendar exif ffi ftp gd gettext imap intl mysqli pcntl pdo_mysql \
	shmop sockets sysvmsg sysvsem sysvshm xsl zip

# Configure PHP-FPM and NGINX
RUN cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY ./config/php.ini $PHP_INI_DIR/conf.d/piwigo.ini
COPY ./config/php-fpm.conf /usr/local/etc/php-fpm.d/zz-piwigo.conf
COPY ./config/nginx.conf /etc/nginx/nginx.conf
RUN mkdir -p /var/www/html/piwigo /var/www/source/
RUN chown nginx:nginx /var/www/html/ /var/www/source/
EXPOSE 80

# Configure postfix to only send mail locally
RUN postconf -e "myhostname = piwigo.local" && postconf -e "inet_interfaces = loopback-only"

# Fetch, extract and install Piwigo
USER nginx
RUN curl -o /tmp/piwigo.zip https://piwigo.org/download/dlcounter.php?code=${PIWIGO_VERSION}
RUN unzip /tmp/piwigo.zip -d /var/www/source/
RUN rm -rf /tmp/piwigo.zip

# Add Tagging file
RUN printf "Unofficial Piwigo container by Tim Hawes\nPiwigo ${PIWIGO_VERSION}\nPHP ${PHP_VERSION}\nBuild Version ${BUILD_VERSION}" > /var/www/html/piwigo-docker.info

# Configure s6-overlay
USER root
COPY --chmod=0755 ./config/s6-rc.d/ /etc/s6-overlay/s6-rc.d/
COPY --chmod=0755 ./config/init-script.sh /init-script.sh
# The base image sets CMD ["php-fpm"] and STOPSIGNAL SIGQUIT; s6-overlay supervises php-fpm itself and expects SIGTERM
STOPSIGNAL SIGTERM
ENTRYPOINT ["/init"]
CMD []
