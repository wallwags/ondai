# Etapa 1: Usa imagem oficial do Composer para instalar dependências PHP
FROM composer:2 AS composer

# Etapa 2: Usa imagem oficial do PHP com FPM (sem nginx)
FROM php:8.2-cli

# Define argumentos (opcionais, mas úteis)
ARG user=laravel
ARG uid=1000

# Define variáveis de ambiente
ENV APP_ENV=production \
    APP_DEBUG=false \
    COMPOSER_ALLOW_SUPERUSER=1 \
    PORT=8080

# Instala pacotes e extensões necessárias
RUN apt-get update && apt-get install -y \
    git \
    curl \
    unzip \
    zip \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libonig-dev \
    libxml2-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    libicu-dev \
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

# Copia o Composer instalado anteriormente
COPY --from=composer /usr/bin/composer /usr/bin/composer

# Cria um novo usuário para evitar rodar como root
RUN useradd -G www-data,root -u $uid -d /home/$user $user \
    && mkdir -p /home/$user/.composer \
    && chown -R $user:$user /home/$user

# Define diretório de trabalho
WORKDIR /var/www

# Copia todos os arquivos do projeto para o container
COPY . .

# Instala dependências do backend Laravel
RUN composer install --no-dev --optimize-autoloader

# Instala dependências do frontend e faz build
RUN npm install && npm run build

# Prepara caches do Laravel
RUN php artisan config:clear && \
    php artisan config:cache && \
    php artisan route:cache && \
    php artisan view:cache

# Ajusta permissões
RUN chown -R $user:www-data /var/www && chmod -R 755 /var/www

# Expõe a porta padrão do Render
EXPOSE 8080

# Troca para o usuário criado
USER $user

# Comando de inicialização usando o servidor embutido do Laravel
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8080"]
