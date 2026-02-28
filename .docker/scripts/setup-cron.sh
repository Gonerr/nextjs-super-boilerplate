#!/bin/bash

# Создаем cron задачу для обновления сертификатов
# Запускаем проверку каждый день в 2:00 утра
echo "0 2 * * * /scripts/renew-certificates.sh >> /var/log/certbot/cron-renewal.log 2>&1" > /etc/crontabs/root

# Устанавливаем права на файл crontab
chmod 0644 /etc/crontabs/root

echo "✅ Cron job for certificate renewal has been set up"
echo "📅 Renewal will run daily at 2:00 AM"
