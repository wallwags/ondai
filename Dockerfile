# =========================
# Etapa 1: Usa imagem oficial do Composer para instalar dependências PHP
# =========================
FROM composer:2 AS composer

# =========================
# Etapa 2: Usa imagem oficial do PHP com FPM para produção (sem servidor embutido)
# =========================
FROM php:8.2-fpm

# =========================
# Define argumentos opcionais para criar usuário não root
# =========================
ARG user=laravel
ARG uid=1000

# =========================
# Define variáveis de ambiente para produção
# =========================
ENV APP_ENV=production \
    APP_DEBUG=false \
    COMPOSER_ALLOW_SUPERUSER=1 \
    PORT=8080

# =========================
# Instala pacotes necessários e extensões PHP usadas pelo Laravel
# Inclui também nodejs, npm, nginx e supervisor para rodar processos juntos
# =========================
RUN apt-get update && apt-get install -y \
    git curl unzip zip \
    libpng-dev libjpeg-dev libfreetype6-dev libzip-dev libonig-dev libxml2-dev libssl-dev libcurl4-openssl-dev libicu-dev \
    nodejs npm \
    nginx supervisor \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo pdo_mysql zip gd mbstring bcmath opcache intl exif \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# =========================
# Copia o Composer da etapa anterior para usar no container final
# =========================
COPY --from=composer /usr/bin/composer /usr/bin/composer

# =========================
# Cria usuário laravel para rodar a aplicação sem root
# =========================
RUN useradd -m -d /home/$user -s /bin/bash -u $uid $user

# =========================
# Define diretório de trabalho para o Laravel dentro do container
# =========================
WORKDIR /var/www

# =========================
# Copia todos os arquivos do projeto para dentro do container
# =========================
COPY . .

# =========================
# Instala dependências PHP sem os pacotes de desenvolvimento
# e otimiza o autoloader para produção
# =========================
RUN composer install --no-dev --optimize-autoloader

# =========================
# Instala dependências JS e roda build do frontend (ex: Laravel Mix ou Vite)
# =========================
RUN npm install && npm run build

# =========================
# Prepara os caches do Laravel para otimizar performance
# =========================
RUN php artisan config:clear && \
    php artisan config:cache && \
    php artisan route:cache && \
    php artisan view:cache

# =========================
# Ajusta permissões para que o usuário laravel e grupo www-data tenham acesso
# Especialmente em storage e bootstrap/cache, que precisam ser graváveis
# =========================
RUN chown -R $user:www-data /var/www/html && chmod -R 755 /var/www/html
RUN chown -R $user:www-data storage bootstrap/cache && chmod -R 775 storage bootstrap/cache

# =========================
# Copia os arquivos de configuração do nginx e supervisor para rodar os serviços
# Esses arquivos devem estar na pasta ./docker no projeto local
# =========================
COPY ./docker/nginx.conf /etc/nginx/nginx.conf
COPY ./docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# =========================
# Expõe a porta 8080 que o Render espera para conectar via HTTP
# =========================
EXPOSE 8080

RUN mkdir -p /var/log/supervisor && chown -R $user:$user /var/log/supervisor
RUN mkdir -p /var/run && chown -R $user:$user /var/run


# =========================
# Troca para o usuário laravel para rodar a aplicação com segurança
# =========================
USER $user

# =========================
# Comando de inicialização:
# Usa o supervisord para rodar php-fpm e nginx juntos em primeiro plano
# =========================
CMD ["supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
