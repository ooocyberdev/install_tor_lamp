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

# Обновление системы
echo -e "${YELLOW}1. Обновление пакетов...${NC}"
apt-get update -y && apt-get upgrade -y
check_error "Не удалось обновить пакеты"

# Установка Apache2
echo -e "${YELLOW}2. Установка Apache2...${NC}"
apt-get install -y apache2
check_error "Ошибка установки Apache2"
systemctl enable --now apache2
check_error "Ошибка запуска Apache2"

# Установка MySQL
echo -e "${YELLOW}3. Установка MySQL...${NC}"
apt-get install -y mysql-server
check_error "Ошибка установки MySQL"
systemctl enable --now mysql
check_error "Ошибка запуска MySQL"

# Безопасная настройка MySQL
echo -e "${YELLOW}4. Настройка MySQL...${NC}"
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'SecurePass123!';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "FLUSH PRIVILEGES;"

# Установка PHP 8.2
echo -e "${YELLOW}5. Установка PHP 8.2...${NC}"
add-apt-repository -y ppa:ondrej/php
check_error "Ошибка добавления PPA"
apt-get update -y
apt-get install -y php8.2 libapache2-mod-php8.2 \
                   php8.2-mysql php8.2-curl \
                   php8.2-gd php8.2-mbstring \
                   php8.2-xml php8.2-zip php8.2-intl
check_error "Ошибка установки PHP"

# Установка phpMyAdmin
echo -e "${YELLOW}6. Установка phpMyAdmin...${NC}"
apt-get install -y phpmyadmin
check_error "Ошибка установки phpMyAdmin"

# Настройка Apache для PHP
echo -e "${YELLOW}7. Настройка Apache для PHP...${NC}"
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

echo "HiddenServiceDir /var/lib/tor/hidden_service/" >> /etc/tor/torrc
echo "HiddenServicePort 80 127.0.0.1:80" >> /etc/tor/torrc
echo "HiddenServicePort 443 127.0.0.1:443" >> /etc/tor/torrc

systemctl restart tor
check_error "Ошибка перезапуска Tor"

# Ожидание генерации onion-адреса
echo -e "${YELLOW}10. Ожидание генерации onion-адреса...${NC}"
for i in {1..6}; do
    if [ -f "/var/lib/tor/hidden_service/hostname" ]; then
        break
    fi
    echo "Попытка $i из 6: ожидание 10 секунд..."
    sleep 10
done

if [ ! -f "/var/lib/tor/hidden_service/hostname" ]; then
    echo -e "${RED}Ошибка: Tor не сгенерировал onion-адрес${NC}"
    echo -e "${YELLOW}Попытка ручной генерации...${NC}"
    sudo -u debian-tor tor --hush -f /etc/tor/torrc --keygen --data-dir /var/lib/tor/hidden_service
    sleep 5
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
        .info { background: #f8f9fa; padding: 15px; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>Ваш сайт работает в Tor сети!</h1>
    
    <div class="info">
        <h2>Основная информация:</h2>
        <p><strong>Onion-адрес:</strong> <span class="success">$ONION_ADDR</span></p>
        <p><strong>Корневая директория сайта:</strong> <span class="success">/var/www/html/</span></p>
        <p><strong>Доступ к phpMyAdmin:</strong> <span class="success">http://$ONION_ADDR/phpmyadmin</span></p>
    </div>
    
    <h2>Системная информация:</h2>
    <p><strong>Версия PHP:</strong> <?php echo phpversion(); ?></p>
    <p><strong>Версия MySQL:</strong> <?php 
        \$link = @mysqli_connect("localhost", "root", "SecurePass123!");
        if (\$link) {
            echo mysqli_get_server_info(\$link);
            mysqli_close(\$link);
        } else {
            echo "<span class='error'>Ошибка подключения: " . mysqli_connect_error() . "</span>";
        }
    ?></p>
    
    <h2>Проверка компонентов:</h2>
    <p>Apache: <span class="success">работает</span></p>
    <p>PHP: <span class="success">работает</span></p>
    <p>MySQL: <?php echo \$link ? "<span class='success'>работает</span>" : "<span class='error'>ошибка</span>"; ?></p>
    <p>Tor: <?php echo (file_exists('/var/lib/tor/hidden_service/hostname')) ? "<span class='success'>работает</span>" : "<span class='error'>ошибка</span>"; ?></p>
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
echo -e "${YELLOW}4. Данные для входа в phpMyAdmin:${NC}"
echo -e "   - Логин: ${GREEN}root${NC}"
echo -e "   - Пароль: ${GREEN}SecurePass123!${NC}"
echo -e "${YELLOW}5. Доступ через:${NC} Tor Browser"
echo -e "\n${YELLOW}Для добавления файлов на сайт:${NC}"
echo -e "sudo cp ваши_файлы /var/www/html/"
echo -e "\n${YELLOW}Лог ошибок Tor:${NC} sudo journalctl -u tor -n 50"
echo -e "${YELLOW}Проверить Apache:${NC} sudo systemctl status apache2"
