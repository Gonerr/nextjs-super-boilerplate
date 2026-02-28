#!/bin/bash

# В начале скрипта
mkdir -p /var/log/certbot
chmod 755 /var/log/certbot
echo "running" > /var/log/certbot/error_status
chmod 644 /var/log/certbot/error_status

# Безопасный рестарт nginx-контейнера и ожидание готовности
restart_nginx_container() {
    echo "🔄 Restarting nginx container before certificate issuance..."
    docker restart core-nginx-service 2>/dev/null || \
    docker kill -s HUP core-nginx-service 2>/dev/null || \
    docker exec core-nginx-service nginx -s reload 2>/dev/null || \
    echo "⚠️ Failed to restart nginx (container may be down)"
}

wait_for_nginx_ready() {
    echo "⏳ Waiting for nginx to become ready on port 80..."
    local hosts=("nginx" "core-nginx-service")
    for i in {1..30}; do
        for host in "${hosts[@]}"; do
            if curl -s -f "http://$host:80/.well-known/acme-challenge/health" > /dev/null; then
                echo "✅ Nginx is ready ($host)"
                return 0
            fi
        done
        sleep 5
    done
    echo "❌ Nginx did not become ready in time"
    return 1
}

restart_nginx_container
wait_for_nginx_ready || true

# Функция для очистки старых сертификатов с суффиксами
cleanup_old_certificates() {
    local domain=$1
    echo "🧹 Cleaning up old certificates with suffixes for $domain"
    
    # Находим все папки с числовыми суффиксами (кроме -old, который мы сохраняем как бэкап)
    old_cert_dirs=$(find /etc/letsencrypt/archive -maxdepth 1 -name "${domain}-*" -type d | grep -E "${domain}-[0-9]+$")
    
    if [ -n "$old_cert_dirs" ]; then
        echo "$old_cert_dirs" | while read -r cert_dir; do
            cert_name=$(basename "$cert_dir")
            suffix="${cert_name#${domain}-}"
            echo "🗑️ Removing old certificate with suffix ${suffix}"
            rm -rf "/etc/letsencrypt/archive/${cert_name}"
            rm -rf "/etc/letsencrypt/live/${cert_name}" 2>/dev/null || true
            rm -f "/etc/letsencrypt/renewal/${cert_name}.conf" 2>/dev/null || true
        done
    else
        echo "ℹ️ No old certificates with numeric suffixes found"
    fi
}

# Проверка наличия существующего сертификата для домена
has_existing_cert() {
    local domain=$1
    [ -f "/etc/letsencrypt/live/${domain}/fullchain.pem" ] && \
    [ -f "/etc/letsencrypt/live/${domain}/privkey.pem" ]
}

# Функция для создания самоподписанного сертификата
create_self_signed_cert() {
    local domain=$1
    echo "Creating self-signed certificate for $domain"
    
    # Создаем все необходимые директории
    mkdir -p "/etc/letsencrypt/live/${domain}"
    mkdir -p "/var/www/certbot/.well-known/acme-challenge"
    
    # Проверяем существование директорий
    echo "Debug: Checking directories..."
    ls -la "/etc/letsencrypt/live/"
    ls -la "/var/www/certbot/.well-known/acme-challenge/"
    
    # Генерируем сертификаты с подробным выводом
    echo "Debug: Generating private key..."
    openssl genrsa -out "/etc/letsencrypt/live/${domain}/privkey.pem" 2048 || {
        echo "Failed to generate private key"
        return 1
    }
    
    echo "Debug: Generating self-signed certificate..."
    openssl req -x509 -new -nodes \
        -key "/etc/letsencrypt/live/${domain}/privkey.pem" \
        -subj "/CN=${domain}" \
        -days 365 \
        -out "/etc/letsencrypt/live/${domain}/fullchain.pem" || {
        echo "Failed to generate certificate"
        return 1
    }
    
    # Проверяем созданные файлы
    echo "Debug: Verifying generated files..."
    openssl x509 -in "/etc/letsencrypt/live/${domain}/fullchain.pem" -text -noout || {
        echo "Invalid certificate generated"
        return 1
    }
    
    # Копируем сертификаты
    cp "/etc/letsencrypt/live/${domain}/fullchain.pem" "/etc/letsencrypt/live/${domain}/cert.pem"
    cp "/etc/letsencrypt/live/${domain}/fullchain.pem" "/etc/letsencrypt/live/${domain}/chain.pem"
    
    # Устанавливаем правильные права
    chmod 644 "/etc/letsencrypt/live/${domain}"/*.pem
    chmod 755 "/etc/letsencrypt/live/${domain}"
    
    # Создаем ACME challenge
    echo "LOCAL_DOMAIN_VERIFICATION_${domain}" > "/var/www/certbot/.well-known/acme-challenge/health"
    chmod -R 755 /var/www/certbot
    
    echo "✅ Self-signed certificate created for ${domain}"
    ls -la "/etc/letsencrypt/live/${domain}"
    return 0
}

# Функция для получения Let's Encrypt сертификата
get_letsencrypt_cert() {
    local domain=$1
    local force_renewal=${2:-false}
    
    # Функция перезагрузки nginx (безопасная)
    reload_nginx() {
        echo "🔁 Reloading nginx to apply new certificates..."
        docker kill -s HUP core-nginx-service 2>/dev/null || \
        docker exec core-nginx-service nginx -s reload 2>/dev/null || \
        docker restart core-nginx-service 2>/dev/null || \
        echo "⚠️ Failed to reload nginx (container may be down)"
    }
    
    # Быстрый выход, если файлы уже существуют в персистентном хранилище
    # НО только если это не принудительное обновление и сертификат валидный
    if has_existing_cert "$domain" && [ "$force_renewal" != "true" ]; then
        echo "Existing cert files found for $domain, skipping issuance"
        ls -la "/etc/letsencrypt/live/${domain}/"
        return 0
    fi

    echo "Requesting Let's Encrypt certificate for $domain (force: $force_renewal)"
    
    # Проверяем существующий сертификат
    # Функция для проверки типа сертификата
    is_letsencrypt_cert() {
        local domain=$1
        local cert_path="/etc/letsencrypt/live/${domain}/cert.pem"
        
        if [ ! -f "$cert_path" ]; then
            return 1
        fi
        
        # Проверяем issuer сертификата
        local issuer=$(openssl x509 -in "$cert_path" -noout -issuer 2>/dev/null | sed 's/issuer=//')
        
        # Let's Encrypt сертификаты имеют issuer содержащий "Let's Encrypt" или "R3"
        if [[ "$issuer" == *"Let's Encrypt"* ]] || [[ "$issuer" == *"R3"* ]] || [[ "$issuer" == *"E1"* ]]; then
            return 0  # Это Let's Encrypt сертификат
        else
            return 1  # Это самоподписанный или другой сертификат
        fi
    }

    if certbot certificates --cert-name "$domain" &>/dev/null; then
        echo "Certificate already exists for $domain"
        
        # Проверяем наличие файлов сертификата
        if [ ! -f "/etc/letsencrypt/live/${domain}/fullchain.pem" ] || \
           [ ! -f "/etc/letsencrypt/live/${domain}/privkey.pem" ]; then
            echo "Certificate files not found, requesting new certificate"
        elif [ "$force_renewal" = "true" ]; then
            echo "Force renewal requested, requesting new certificate"
        elif ! is_letsencrypt_cert "$domain"; then
            echo "Existing certificate is not from Let's Encrypt, will request new LE cert without removing current"
        else
            echo "Let's Encrypt certificate exists and is valid, skipping"
            ls -la "/etc/letsencrypt/live/${domain}/"
            return 0
        fi
    elif [ "$force_renewal" = "true" ] && ! is_letsencrypt_cert "$domain"; then
        echo "Force renewal requested and existing certificate is not from Let's Encrypt, will obtain new LE cert without removing current"
    fi
    
    # Проверяем доступность директории для webroot
    if [ ! -d "/var/www/certbot" ]; then
        mkdir -p /var/www/certbot
    fi
    
    # Подготавливаем параметры для certbot
    local certbot_params=(
        "--webroot"
        "-w=/var/www/certbot"
        "-d=${domain}"
        "--expand"
        "--keep-until-expiring"
        "--cert-name=${domain}"
        "--verbose"
        "--non-interactive"
        "--email=${CERTBOT_EMAIL:-example@example.com}"
        "--agree-tos"
    )
    # Опционально использовать staging CA для отладки
    if [[ "${CERTBOT_USE_STAGING:-false}" = "true" ]]; then
        certbot_params+=("--server" "https://acme-staging-v02.api.letsencrypt.org/directory")
    fi
    
    # Добавляем принудительное обновление если нужно
    if [ "$force_renewal" = "true" ]; then
        certbot_params+=("--force-renewal")
        # Не трогаем текущий lineage до успешного выпуска нового сертификата
    fi
    
    # Запрашиваем сертификат
    certbot certonly "${certbot_params[@]}"
    rc=$?
    if [ $rc -eq 0 ]; then
        echo "✅ Certificate obtained successfully for $domain"
        
        # Проверяем, создался ли сертификат с числовым суффиксом
        new_cert_dir=$(find /etc/letsencrypt/archive -maxdepth 1 -name "${domain}-*" -type d | grep -E "${domain}-[0-9]+$" | head -1)
        if [ -n "$new_cert_dir" ]; then
            new_cert_name=$(basename "$new_cert_dir")
            echo "🔄 New certificate created with suffix ${new_cert_name#${domain}-}, reorganizing..."
            
            # Переименовываем старую папку (если есть) в -old
            if [ -d "/etc/letsencrypt/archive/${domain}" ]; then
                echo "📁 Moving old certificate to -old suffix..."
                mv "/etc/letsencrypt/archive/${domain}" "/etc/letsencrypt/archive/${domain}-old"
                mv "/etc/letsencrypt/live/${domain}" "/etc/letsencrypt/live/${domain}-old" 2>/dev/null || true
                mv "/etc/letsencrypt/renewal/${domain}.conf" "/etc/letsencrypt/renewal/${domain}-old.conf" 2>/dev/null || true
            fi
            
            # Переименовываем новую папку в основную
            echo "📁 Moving new certificate to main name..."
            mv "/etc/letsencrypt/archive/${new_cert_name}" "/etc/letsencrypt/archive/${domain}"
            mv "/etc/letsencrypt/live/${new_cert_name}" "/etc/letsencrypt/live/${domain}" 2>/dev/null || true
            mv "/etc/letsencrypt/renewal/${new_cert_name}.conf" "/etc/letsencrypt/renewal/${domain}.conf" 2>/dev/null || true
            
            # Создаем правильные симлинки
            echo "🔗 Creating correct symlinks..."
            rm -f "/etc/letsencrypt/live/${domain}"/*.pem
            ln -s "../../archive/${domain}/cert1.pem" "/etc/letsencrypt/live/${domain}/cert.pem"
            ln -s "../../archive/${domain}/chain1.pem" "/etc/letsencrypt/live/${domain}/chain.pem"
            ln -s "../../archive/${domain}/fullchain1.pem" "/etc/letsencrypt/live/${domain}/fullchain.pem"
            ln -s "../../archive/${domain}/privkey1.pem" "/etc/letsencrypt/live/${domain}/privkey.pem"
            
            echo "✅ Certificate reorganized successfully"
        fi
        
        ls -la "/etc/letsencrypt/live/${domain}"
        reload_nginx
        return 0
    fi
    echo "❌ Failed to obtain certificate for $domain (rc=$rc)"
    # Если достигнут лимит выпусков, пытаемся использовать уже существующие файлы или fallback
    if grep -qi "too many certificates" /var/log/letsencrypt/letsencrypt.log 2>/dev/null; then
        if has_existing_cert "$domain"; then
            echo "Rate limit hit, but existing cert files found — reusing"
            return 0
        else
            echo "Rate limit hit and no existing files — generating self-signed for continuity"
            create_self_signed_cert "$domain"
            return $?
        fi
    fi
    return 1
}

# Проверяем доступность nginx
echo "Checking nginx configuration and availability..."
for i in {1..3}; do
    echo "Attempt $i: Checking nginx status..."
    if curl --connect-timeout 5 -I http://nginx:80 > /dev/null 2>&1; then
        echo "✅ Successfully connected to nginx"
        break
    fi
    echo "❌ Cannot connect to nginx"
    if [ $i -eq 3 ]; then
        echo "❌ Failed to connect to nginx after 3 attempts"
        echo "nginx_connection_failed" > /var/log/certbot/error_status
        exit 1
    fi
    sleep 5
done

# Проверяем, был ли скрипт вызван с флагом принудительного обновления
FORCE_RENEWAL=false
if [ "$1" = "--force-renewal" ]; then
    FORCE_RENEWAL=true
    echo " Force renewal mode enabled"
fi

# Преобразуем строку с доменами в массив
IFS=',' read -ra DOMAIN_ARRAY <<< "$DOMAINS"
for domain in "${DOMAIN_ARRAY[@]}"; do
    echo " Processing domain: $domain"
    
    # Очищаем старые сертификаты с суффиксами
    cleanup_old_certificates "$domain"
    
    # Проверяем локальные домены ПЕРЕД тестовым режимом
    if [[ "$domain" =~ [.]127[.]0[.]0[.]1[.] ]] || \
       [[ "$domain" =~ [.]localhost ]] || \
       [[ "$domain" =~ [.]local$ ]] || \
       [[ "$domain" =~ [.]local[,]? ]]; then
        echo "🔧 Local domain detected, using self-signed certificate"
        create_self_signed_cert "$domain"
    # Потом проверяем тестовый режим
    elif [[ "${CERTBOT_TEST_MODE:-false}" = "true" ]]; then
        echo " Test mode enabled, using self-signed certificate"
        create_self_signed_cert "$domain"
    else
        echo "🌐 Production domain detected, using Let's Encrypt"
        get_letsencrypt_cert "$domain" "$FORCE_RENEWAL"
    fi
done

echo "🎉 All certificates have been processed"

# В конце скрипта
if [ $? -eq 0 ]; then
    echo "success" > /var/log/certbot/error_status
else
    echo "certificate_generation_failed" > /var/log/certbot/error_status
fi
