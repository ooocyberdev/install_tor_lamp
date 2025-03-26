#!/bin/bash

# Проверка на root-права
if [ "$(id -u)" -ne 0 ]; then
  echo "Этот скрипт должен запускаться с правами root!" >&2
  exit 1
fi

# Генерация случайного пароля для MySQL root (16 символов)
DB_ROOT_PASSWORD=$(openssl rand -base64 16 | tr -d '+=/' | cut -c1-16)

# Обновление системы
echo "🔄 Обновление пакетов системы..."
apt-get update && apt-get upgrade -y

# Установка Apache и MySQL
echo "🔧 Установка Apache и MySQL..."
apt-get install -y apache2 mysql-server

# Установка PHP 8.x (последней версии)
echo "🐘 Установка PHP 8.x..."
apt-get install -y software-properties-common
add-apt-repository -y ppa:ondrej/php
apt-get update
apt-get install -y php8.2 php8.2-mysql libapache2-mod-php8.2 php8.2-common php8.2-mbstring

# Настройка MySQL с автоматическим паролем
echo "🔐 Настройка MySQL (пароль root: $DB_ROOT_PASSWORD)..."
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_ROOT_PASSWORD}';"
mysql -e "FLUSH PRIVILEGES;"

# Установка phpMyAdmin с автоматической настройкой
echo "📊 Установка phpMyAdmin..."
debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password ${DB_ROOT_PASSWORD}"
debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password ${DB_ROOT_PASSWORD}"
debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password ${DB_ROOT_PASSWORD}"
debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"
apt-get install -y phpmyadmin

# Настройка Apache для phpMyAdmin
echo "🔧 Настройка Apache..."
ln -s /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf
a2enconf phpmyadmin
systemctl reload apache2

# Установка Tor
echo "🧅 Установка Tor..."
apt-get install -y tor

# Настройка Tor (создание .onion-сайта)
echo "🌐 Настройка скрытого сервиса Tor..."
mkdir -p /var/www/tor-site
chown www-data:www-data /var/www/tor-site
chmod 700 /var/www/tor-site

cat >> /etc/tor/torrc <<EOL
HiddenServiceDir /var/lib/tor/hidden_service/
HiddenServicePort 80 127.0.0.1:80
EOL

# Создание тестовой страницы с PHP-инфо
echo "📝 Создание тестовой страницы (index.php)..."
cat > /var/www/tor-site/index.php <<EOL
<html>
<head><title>Onion Site (PHP 8.x)</title></head>
<body>
<h1>Добро пожаловать на ваш onion-сайт!</h1>
<p>Это тестовая страница вашего скрытого сервиса.</p>
<p>Версия PHP: <?php echo phpversion(); ?></p>
<p>Доступ к phpMyAdmin: <a href="/phpmyadmin">/phpmyadmin</a></p>
<hr>
<h3>Информация о PHP:</h3>
<?php phpinfo(); ?>
</body>
</html>
EOL

# Настройка виртуального хоста Apache
cat > /etc/apache2/sites-available/tor-site.conf <<EOL
<VirtualHost *:80>
    ServerAdmin admin@onion
    DocumentRoot /var/www/tor-site
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
    <Directory /var/www/tor-site>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOL

a2dissite 000-default
a2ensite tor-site
systemctl reload apache2

# Перезапуск Tor
echo "🔄 Перезапуск Tor..."
systemctl restart tor

# Ожидание создания .onion-адреса
echo "⏳ Ожидание создания .onion-адреса..."
sleep 10

# Получение .onion-адреса
ONION_ADDRESS=$(cat /var/lib/tor/hidden_service/hostname 2>/dev/null)

# Вывод информации
echo ""
echo "=============================================="
echo "✅ Установка завершена!"
echo ""
echo "🌐 Onion URL: http://${ONION_ADDRESS}"
echo ""
echo "🔑 Данные для подключения к MySQL:"
echo "   Хост: localhost"
echo "   Пользователь: root"
echo "   Пароль: ${DB_ROOT_PASSWORD}"
echo "   Порт: 3306"
echo ""
echo "📂 Корневая директория сайта: /var/www/tor-site"
echo "📊 phpMyAdmin: http://${ONION_ADDRESS}/phpmyadmin"
echo ""
echo "⚠️ ВАЖНО: Сохраните эти данные, особенно пароль MySQL!"
echo "=============================================="
echo ""
