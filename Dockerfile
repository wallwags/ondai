# Etapa 1 - Composer
FROM composer:2 AS composer

# Etapa 2 - PHP com extensões
FROM php:8.2-fpm

# Argumentos para criar usuário
ARG user=laravel
ARG uid=1000

# Variáveis de ambiente
ENV APP_ENV=production \
    APP_DEBUG=false \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS=0 \
    COMPOSER_ALLOW_SUPERUSER=1

# Instala dependências do sistema
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libzip-dev \
    zip \
    unzip \
    cron \
    nano \
    libonig-dev \
    libxml2-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    libpq-dev \
    libicu-dev \
    libjpeg-dev \
    libxslt1-dev \
    supervisor \
    ca-certificates \
    gnupg \
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

# Instala Node.js 18.x
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs

# Instala Composer
COPY --from=composer /usr/bin/composer /usr/bin/composer

# Cria usuário não-root
RUN useradd -G www-data,root -u $uid -d /home/$user $user \
    && mkdir -p /home/$user/.composer \
    && chown -R $user:$user /home/$user

# Define diretório de trabalho
WORKDIR /var/www

# Copia arquivos do projeto
COPY . .

# Instala dependências
RUN composer install --no-dev --optimize-autoloader \
    && npm install \
    && npm run build

# Permissões e caches Laravel
RUN chown -R $user:www-data /var/www \
    && chmod -R 755 /var/www \
    && php artisan config:clear \
    && php artisan config:cache \
    && php artisan route:cache \
    && php artisan view:cache

# Porta do PHP-FPM
EXPOSE 9000

# Define usuário
USER $user

# Comando final
# CMD ["php-fpm"]
CMD php artisan serve --host=0.0.0.0 --port=10000
