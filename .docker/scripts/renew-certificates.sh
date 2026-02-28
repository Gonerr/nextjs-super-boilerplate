#!/bin/bash

echo "Starting certificate renewal check at $(date)"

# Проверяем доступность docker.sock для deploy-hook
if [ ! -S "/var/run/docker.sock" ]; then
    echo "❌ Warning: Docker socket not available, deploy-hook may not work"
fi

# Гарантируем наличие webroot и health файла для ACME
mkdir -p /var/www/certbot/.well-known/acme-challenge
echo OK > /var/www/certbot/.well-known/acme-challenge/health

# Безопасный рестарт nginx-контейнера и ожидание готовности
restart_nginx_container() {
    echo "🔄 Restarting nginx container before certificate operations..."
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
if ! wait_for_nginx_ready; then
    echo "❌ Warning: Nginx is not available on port 80 after restart, skipping renewal for now"
    exit 0
fi

# Функция для определения типа сертификата
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

# Функция для исправления симлинков сертификатов
fix_certificate_symlinks() {
    local domain=$1
    echo "🔧 Checking and fixing certificate symlinks for $domain"
    
    # Ищем папку с любым числовым суффиксом
    new_cert_dir=$(find /etc/letsencrypt/archive -maxdepth 1 -name "${domain}-*" -type d | grep -E "${domain}-[0-9]+$" | head -1)
    if [ -n "$new_cert_dir" ]; then
        new_cert_name=$(basename "$new_cert_dir")
        echo "📁 Found certificate with suffix ${new_cert_name#${domain}-}, reorganizing to main name..."
        
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
        
        echo "✅ Certificate reorganized and symlinks fixed for $domain"
        return 0
    fi
    return 1
}

# Функция для принудительного перевыпуска сертификата
force_reissue_cert() {
    local domain=$1
    echo "🔄 Force reissuing certificate for $domain (current cert is not Let's Encrypt)"
    
    # Функция перезагрузки nginx (безопасная)
    reload_nginx() {
        echo "🔁 Reloading nginx to apply new certificates..."
        docker kill -s HUP core-nginx-service 2>/dev/null || \
        docker exec core-nginx-service nginx -s reload 2>/dev/null || \
        docker restart core-nginx-service 2>/dev/null || \
        echo "⚠️ Failed to reload nginx (container may be down)"
    }

    # Не удаляем действующий сертификат заранее; получаем новый и только потом переключаемся
    
    # Вызываем get-certificates.sh для создания нового
    echo "🆕 Creating new certificate..."
    /scripts/get-certificates.sh --force-renewal
    
    # Исправляем симлинки после создания нового сертификата (атомарное переключение)
    fix_certificate_symlinks "$domain"
    
    reload_nginx
}

# Повторная лёгкая проверка доступности nginx (на случай гонок)
NGINX_OK=false
for host in nginx core-nginx-service; do
    if curl -s -f http://$host:80/.well-known/acme-challenge/health > /dev/null; then
        NGINX_OK=true
        break
    fi
done
if [ "$NGINX_OK" != true ]; then
    echo "❌ Warning: Nginx is not available on port 80, skipping renewal for now"
    # Возвращаем 0, чтобы supervisor не перезапускал задачу по ошибке; cron запустит позже
    exit 0
fi

# Поддержка принудительного обновления: аргумент --force или env FORCE_RENEWAL=true
FORCE_RENEWAL_MODE=false
if [ "${1:-}" = "--force" ] || [ "${FORCE_RENEWAL:-false}" = "true" ]; then
    FORCE_RENEWAL_MODE=true
    echo "⚙️  Force renewal mode enabled"
fi

# Преобразуем строку с доменами в массив
IFS=',' read -ra DOMAIN_ARRAY <<< "$DOMAINS"

# Флаг для отслеживания общего результата
renewal_failed=false

# Проверяем каждый домен
for domain in "${DOMAIN_ARRAY[@]}"; do
    echo "📝 Processing domain: $domain"
    
    # Пропускаем обновление для локальных доменов и тестового режима
    if [[ "$domain" == *".127.0.0.1."* ]] || [[ "$domain" == *".localhost"* ]] || [[ "${CERTBOT_TEST_MODE:-false}" = "true" ]]; then
        echo "🔧 Local/Test domain detected, skipping renewal for $domain"
        continue
    fi
    
    echo "🔄 Checking renewal for $domain"

    # В режиме принудительного обновления сначала проверяем тип сертификата
    if [ "$FORCE_RENEWAL_MODE" = true ]; then
        if ! is_letsencrypt_cert "$domain"; then
            echo "⚠️ Current certificate is not Let's Encrypt. Reissuing by removing existing lineage..."
            force_reissue_cert "$domain"
            continue
        fi

        FORCE_ARGS=(
            certonly
            --domains "$domain"
            --webroot -w /var/www/certbot
            --cert-name "$domain"
            --deploy-hook "docker kill -s HUP core-nginx-service"
            --non-interactive
            --force-renewal
            --disable-hook-validation
        )
        if [[ "${CERTBOT_USE_STAGING:-false}" = "true" ]]; then
            FORCE_ARGS+=(--server "https://acme-staging-v02.api.letsencrypt.org/directory")
        fi
        if certbot "${FORCE_ARGS[@]}"; then
            echo "✅ Force renewal completed successfully for $domain"
            # Перезагружаем nginx после успешного обновления
            docker kill -s HUP core-nginx-service 2>/dev/null || \
            docker exec core-nginx-service nginx -s reload 2>/dev/null || \
            docker restart core-nginx-service 2>/dev/null || \
            echo "⚠️ Failed to reload nginx (container may be down)"
        else
            echo "❌ Force renewal failed for $domain"
            renewal_failed=true
        fi
        continue
    fi
    
    # Проверяем, существует ли сертификат
    cert_path="/etc/letsencrypt/live/${domain}/fullchain.pem"
    if [ ! -f "$cert_path" ]; then
        echo "ℹ️ Certificate not found for $domain, will be created by certbot-init"
        continue
    fi
    
    # Проверяем тип сертификата
    if ! is_letsencrypt_cert "$domain"; then
        echo "⚠️ Current certificate for $domain is not from Let's Encrypt"
        
        # Сначала попробуем исправить симлинки (возможно, есть новый сертификат с -0001)
        if fix_certificate_symlinks "$domain"; then
            echo "✅ Fixed symlinks, certificate should now be Let's Encrypt"
            continue
        fi
        
        if [ "$FORCE_RENEWAL_MODE" = true ]; then
            echo "🔄 Force mode enabled, reissuing certificate..."
            force_reissue_cert "$domain"
            continue
        else
            echo "🔄 Attempting to get Let's Encrypt certificate (current is self-signed)"
            # Пытаемся получить Let's Encrypt сертификат, но не удаляем существующий
            # Если не получится - оставим самоподписанный
            /scripts/get-certificates.sh --force-renewal
            # После получения нового сертификата исправляем симлинки
            fix_certificate_symlinks "$domain"
            continue
        fi
    fi
    
    # Проверяем срок действия сертификата: истечёт ли в ближайшие 30 дней (2592000 сек)
    if openssl x509 -checkend 2592000 -noout -in "$cert_path" > /dev/null 2>&1; then
        echo "✅ Certificate for $domain is valid for more than 30 days"
    else
        echo "🔄 Certificate for $domain will expire within 30 days, attempting renewal"
            
            # Пробуем обновить сертификат
            RENEW_ARGS=(
                renew
                --webroot -w /var/www/certbot
                --cert-name "$domain"
                --deploy-hook "docker kill -s HUP core-nginx-service"
                --non-interactive
                --quiet
                --disable-hook-validation
            )
            if [[ "${CERTBOT_USE_STAGING:-false}" = "true" ]]; then
                RENEW_ARGS+=(--server "https://acme-staging-v02.api.letsencrypt.org/directory")
            fi
            if certbot "${RENEW_ARGS[@]}"; then
                echo "✅ Certificate renewal completed successfully for $domain"
            else
                echo "❌ Certificate renewal failed for $domain, trying force renewal"
                
                # Принудительное обновление
                FORCE_ARGS=(
                    certonly
                    --domains "$domain"
                    --webroot -w /var/www/certbot
                    --cert-name "$domain"
                    --deploy-hook "docker kill -s HUP core-nginx-service"
                    --non-interactive
                    --force-renewal
                    --disable-hook-validation
                )
                if [[ "${CERTBOT_USE_STAGING:-false}" = "true" ]]; then
                    FORCE_ARGS+=(--server "https://acme-staging-v02.api.letsencrypt.org/directory")
                fi
                if certbot "${FORCE_ARGS[@]}"; then
                    echo "✅ Force renewal completed successfully for $domain"
                else
                    echo "❌ Force renewal also failed for $domain"
                    renewal_failed=true
                fi
            fi
    fi
done

# Если обновление не удалось, пробуем получить новые сертификаты
if [ "$renewal_failed" = true ]; then
    echo "🔄 Some renewals failed, attempting to get new certificates"
    /scripts/get-certificates.sh --force-renewal
fi

echo "🎉 Certificate renewal process completed at $(date)"
exit 0
