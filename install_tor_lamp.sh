#!/bin/bash

# Проверка root-прав
if [ "$(id -u)" -ne 0 ]; then
    echo "Запустите скрипт с правами root: sudo $0" >&2
    exit 1
fi

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Функция проверки ошибок
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ОШИБКА] $1${NC}" >&2
        exit 1
    fi
}

echo -e "${YELLOW}=== Начало установки LAMP + Tor ===${NC}"

# Установка базовых зависимостей
echo -e "${YELLOW}1. Установка необходимых компонентов...${NC}"
apt-get install -y software-properties-common curl gnupg2
check_error "Ошибка установки зависимостей"

# Обновление системы
echo -e "${YELLOW}2. Обновление пакетов...${NC}"
apt-get update -y && apt-get upgrade -y
check_error "Не удалось обновить пакеты"

# Установка Apache2
echo -e "${YELLOW}3. Установка Apache2...${NC}"
apt-get install -y apache2
check_error "Ошибка установки Apache2"
systemctl enable --now apache2
check_error "Ошибка запуска Apache2"

# Установка MySQL (без изменения пароля)
echo -e "${YELLOW}4. Установка MySQL...${NC}"
if ! command -v mysql &> /dev/null; then
    apt-get install -y mysql-server
    check_error "Ошибка установки MySQL"
    systemctl enable --now mysql
    check_error "Ошибка запуска MySQL"
else
    echo -e "${YELLOW}MySQL уже установлен, используем существующую конфигурацию${NC}"
fi

# Установка PHP из официального PPA
echo -e "${YELLOW}5. Установка PHP 8.2...${NC}"
LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
check_error "Ошибка добавления PPA"
apt-get update -y
apt-get install -y php8.2 libapache2-mod-php8.2 \
                   php8.2-mysql php8.2-curl \
                   php8.2-gd php8.2-mbstring \
                   php8.2-xml php8.2-zip php8.2-intl
check_error "Ошибка установки PHP"

# Установка phpMyAdmin (пропускаем настройку пароля)
echo -e "${YELLOW}6. Установка phpMyAdmin...${NC}"
apt-get install -y phpmyadmin
check_error "Ошибка установки phpMyAdmin"

# Настройка Apache
echo -e "${YELLOW}7. Настройка Apache...${NC}"
sed -i 's/index.html/index.php index.html/' /etc/apache2/mods-enabled/dir.conf
ln -s /usr/share/phpmyadmin /var/www/html/phpmyadmin
systemctl restart apache2
check_error "Ошибка перезапуска Apache2"

# Установка Tor
echo -e "${YELLOW}8. Установка Tor...${NC}"
apt-get install -y tor
check_error "Ошибка установки Tor"

# Настройка скрытого сервиса
echo -e "${YELLOW}9. Настройка скрытого сервиса Tor...${NC}"
mkdir -p /var/lib/tor/hidden_service
chown debian-tor:debian-tor /var/lib/tor/hidden_service
chmod 700 /var/lib/tor/hidden_service

cat >> /etc/tor/torrc <<EOF
HiddenServiceDir /var/lib/tor/hidden_service/
HiddenServicePort 80 127.0.0.1:80
HiddenServicePort 443 127.0.0.1:443
EOF

systemctl restart tor
check_error "Ошибка перезапуска Tor"

# Ожидание генерации onion-адреса
echo -e "${YELLOW}10. Ожидание генерации onion-адреса...${NC}"
for i in {1..12}; do
    if [ -f "/var/lib/tor/hidden_service/hostname" ]; then
        break
    fi
    echo "Попытка $i из 12: ожидание 10 секунд..."
    sleep 10
done

if [ ! -f "/var/lib/tor/hidden_service/hostname" ]; then
    echo -e "${RED}Ошибка: Tor не сгенерировал onion-адрес${NC}"
    echo -e "${YELLOW}Попытка ручной генерации...${NC}"
    sudo -u debian-tor tor --hush -f /etc/tor/torrc --keygen --data-dir /var/lib/tor/hidden_service
    sleep 10
fi

# Создание тестовой страницы
echo -e "${YELLOW}11. Создание тестовой страницы...${NC}"
ONION_ADDR=$(cat /var/lib/tor/hidden_service/hostname 2>/dev/null || echo "не_найден.onion")

cat > /var/www/html/index.php <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Сайт в Tor сети</title>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        .success { color: #2ecc71; }
        .error { color: #e74c3c; }
        .info { background: #f8f9fa; padding: 15px; border-radius: 5px; margin: 20px 0; }
    </style>
</head>
<body>
    <h1>Ваш сайт работает в Tor сети!</h1>
    
    <div class="info">
        <h2>Основная информация:</h2>
        <p><strong>Onion-адрес:</strong> <span class="success">$ONION_ADDR</span></p>
        <p><strong>Корневая директория сайта:</strong> <span class="success">/var/www/html/</span></p>
        <p><strong>Доступ к phpMyAdmin:</strong> <span class="success">http://$ONION_ADDR/phpmyadmin</span></p>
        <p><strong>Примечание:</strong> Используются текущие учётные данные MySQL сервера</p>
    </div>
</body>
</html>
EOF

chown -R www-data:www-data /var/www/html/

# Итоговая информация
clear
echo -e "${GREEN}=== Установка завершена успешно! ===${NC}"
echo -e "${YELLOW}1. Ваш onion-адрес:${NC} ${GREEN}http://$ONION_ADDR${NC}"
echo -e "${YELLOW}2. Корневая директория сайта:${NC} ${GREEN}/var/www/html/${NC}"
echo -e "${YELLOW}3. phpMyAdmin доступен по:${NC} ${GREEN}http://$ONION_ADDR/phpmyadmin${NC}"
echo -e "${YELLOW}4. Используются текущие учётные данные MySQL сервера${NC}"
echo -e "${YELLOW}5. Доступ через:${NC} Tor Browser"
