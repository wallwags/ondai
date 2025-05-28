# Etapa 1 - Composer
FROM composer:2 AS composer

# Etapa 2 - PHP com extensões e ambiente de produção
FROM php:8.2-fpm

# Argumentos
ARG user=laravel
ARG uid=1000

# Variáveis de ambiente
ENV APP_ENV=production \
    APP_DEBUG=false \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS=0 \
    COMPOSER_ALLOW_SUPERUSER=1

# Instala pacotes
RUN apt-get update && apt-get install -y \
    nginx \
    supervisor \
    git \
    curl \
    unzip \
    zip \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libzip-dev \
    libonig-dev \
    libxml2-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    libpq-dev \
    libicu-dev \
    libjpeg-dev \
    libxslt1-dev \
    gnupg \
    cron \
    nano \
    nodejs \
    npm \
    && docker-php-ext-install \
        pdo \
        pdo_mysql \
        zip \
        gd \
        mbstring \
        bcmath \
        opcache \
        intl \
        exif

# Instala Composer
COPY --from=composer /usr/bin/composer /usr/bin/composer

# Cria usuário
RUN useradd -G www-data,root -u $uid -d /home/$user $user \
    && mkdir -p /home/$user/.composer \
    && chown -R $user:$user /home/$user

# Diretório da aplicação
WORKDIR /var/www

# Copia arquivos do projeto
COPY . .

# Instala dependências Laravel + frontend
RUN composer install --no-dev --optimize-autoloader \
    && npm install \
    && npm run build

# Caches Laravel
RUN chown -R $user:www-data /var/www \
    && chmod -R 755 /var/www \
    && php artisan config:clear \
    && php artisan config:cache \
    && php artisan route:cache \
    && php artisan view:cache

# Copia configs do nginx e supervisor
COPY ./docker/nginx.conf /etc/nginx/nginx.conf
COPY ./docker/supervisord.conf /etc/supervisord.conf

# Expor porta padrão (Render escuta em 8080)
EXPOSE 8080

# Define usuário
USER $user
# Verifica supervisord.conf
RUN test -f /etc/supervisord.conf || (echo "supervisord.conf não encontrado!" && exit 1)

# Garante que diretório de logs do Nginx existe
RUN mkdir -p /var/log/nginx
RUN nginx -t

# Inicia NGINX e PHP-FPM juntos
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
