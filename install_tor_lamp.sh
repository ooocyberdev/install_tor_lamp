#!/bin/bash

# Проверка на root
if [ "$(id -u)" -ne 0 ]; then
    echo "Запустите скрипт с правами root: sudo $0" >&2
    exit 1
fi

# Обновление системы
echo "Обновление пакетов..."
apt update -y && apt upgrade -y
apt install -y software-properties-common apt-transport-https

# Установка последнего Apache
echo "Установка Apache2..."
apt install -y apache2
systemctl enable --now apache2

# Установка последнего MySQL (8.0+)
echo "Установка MySQL..."
apt install -y mysql-server
systemctl enable --now mysql

# Безопасная настройка MySQL
echo "Настройка MySQL..."
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'SecurePass123!';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -e "FLUSH PRIVILEGES;"

# Установка последнего PHP (8.x)
echo "Установка PHP и модулей..."
add-apt-repository -y ppa:ondrej/php
apt update -y
apt install -y php8.2 libapache2-mod-php8.2 \
               php8.2-mysql php8.2-curl php8.2-gd \
               php8.2-mbstring php8.2-xml php8.2-zip \
               php8.2-intl

# Настройка Apache для PHP
echo "Настройка Apache..."
sed -i 's/index.html/index.php index.html/' /etc/apache2/mods-enabled/dir.conf
systemctl restart apache2

# Установка и настройка Tor
echo "Установка Tor..."
apt install -y tor

# Создание скрытого сервиса
echo "Настройка скрытого сервиса Tor..."
echo "HiddenServiceDir /var/lib/tor/hidden_service/" >> /etc/tor/torrc
echo "HiddenServicePort 80 127.0.0.1:80" >> /etc/tor/torrc
systemctl enable --now tor

# Ожидание генерации onion-адреса
echo "Генерация onion-адреса... (может занять до минуты)"
sleep 30 # Даем время Tor сгенерировать адрес

# Создание тестовой страницы
echo "Создание тестовой страницы..."
cat > /var/www/html/index.php <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Сайт в Tor сети</title>
    <meta charset="UTF-8">
</head>
<body>
    <h1>Ваш сайт работает в Tor сети!</h1>
    <p>Apache, PHP и MySQL успешно настроены.</p>
    <p>Версия PHP: <?php echo phpversion(); ?></p>
    <p>Onion-адрес: $(cat /var/lib/tor/hidden_service/hostname)</p>
    <p>MySQL версия: <?php 
        \$link = mysqli_connect("localhost", "root", "SecurePass123!");
        echo mysqli_get_server_info(\$link);
        mysqli_close(\$link);
    ?></p>
</body>
</html>
EOF

chown -R www-data:www-data /var/www/html/

# Вывод информации
ONION_ADDR=$(cat /var/lib/tor/hidden_service/hostname 2>/dev/null)
clear
echo "=== Установка завершена ==="
echo "1. Ваш сайт доступен по onion-адресу: http://${ONION_ADDR}"
echo "2. Apache работает на стандартном порту 80 (доступен только через Tor)"
echo "3. PHP версии $(php -r 'echo phpversion();') установлен"
echo "4. MySQL root пароль: SecurePass123!"
echo "5. Для управления MySQL: mysql -u root -p"
echo ""
echo "Проверить работу PHP можно по ссылке: http://${ONION_ADDR}/index.php"
echo "Для доступа используйте браузер Tor (Tor Browser)"
