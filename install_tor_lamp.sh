#!/bin/bash

# Проверка на root-права
if [ "$(id -u)" -ne 0 ]; then
  echo "Этот скрипт должен запускаться с правами root" >&2
  exit 1
fi

# Генерация случайного пароля для MySQL root
DB_ROOT_PASSWORD=$(openssl rand -base64 16 | tr -d '+=/' | cut -c1-16)

# Обновление системы
echo "Обновление пакетов системы..."
apt-get update && apt-get upgrade -y

# Установка LAMP
echo "Установка Apache, PHP, MySQL..."
apt-get install -y apache2 mysql-server php libapache2-mod-php php-mysql

# Настройка MySQL с автоматическим паролем
echo "Настройка MySQL с автоматически сгенерированным паролем..."
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_ROOT_PASSWORD}';"
mysql -e "FLUSH PRIVILEGES;"

# Установка phpMyAdmin с автоматической настройкой
echo "Установка phpMyAdmin..."
debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password ${DB_ROOT_PASSWORD}"
debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password ${DB_ROOT_PASSWORD}"
debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password ${DB_ROOT_PASSWORD}"
debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"
apt-get install -y phpmyadmin

# Настройка Apache для phpMyAdmin
echo "Настройка Apache для phpMyAdmin..."
ln -s /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf
a2enconf phpmyadmin
systemctl reload apache2

# Установка TOR
echo "Установка TOR..."
apt-get install -y tor

# Настройка TOR для скрытого сервиса
echo "Настройка TOR скрытого сервиса..."
mkdir -p /var/www/tor-site
chown www-data:www-data /var/www/tor-site
chmod 700 /var/www/tor-site

cat >> /etc/tor/torrc <<EOL
HiddenServiceDir /var/lib/tor/hidden_service/
HiddenServicePort 80 127.0.0.1:80
EOL

# Создание тестовой страницы
echo "Создание тестовой страницы..."
cat > /var/www/tor-site/index.html <<EOL
<html>
<head><title>Onion Site</title></head>
<body>
<h1>Добро пожаловать на ваш onion сайт!</h1>
<p>Это тестовая страница вашего скрытого сервиса.</p>
<p>Доступ к phpMyAdmin: <a href="/phpmyadmin">/phpmyadmin</a></p>
</body>
</html>
EOL

# Настройка Apache для tor-site
cat > /etc/apache2/sites-available/tor-site.conf <<EOL
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/tor-site
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOL

a2dissite 000-default
a2ensite tor-site
systemctl reload apache2

# Перезапуск TOR
echo "Перезапуск TOR..."
systemctl restart tor

# Ожидание создания onion-адреса
echo "Ожидание создания onion-адреса..."
sleep 10

# Вывод информации
ONION_ADDRESS=$(cat /var/lib/tor/hidden_service/hostname 2>/dev/null)

echo ""
echo "=============================================="
echo "Установка завершена!"
echo "Onion URL: http://${ONION_ADDRESS}"
echo ""
echo "Данные для подключения к MySQL:"
echo "Хост: localhost"
echo "Пользователь: root"
echo "Пароль: ${DB_ROOT_PASSWORD}"
echo "Порт: 3306"
echo ""
echo "Корневая директория сайта: /var/www/tor-site"
echo "phpMyAdmin доступен по пути: /phpmyadmin"
echo ""
echo "ВАЖНО: Сохраните эти данные, особенно пароль root MySQL!"
echo "=============================================="
echo ""
