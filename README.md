# 🚀 Автоматическая установка LAMP + Tor + phpMyAdmin

![Bash](https://img.shields.io/badge/-Bash-4EAA25?logo=gnu-bash&logoColor=white)
![Apache](https://img.shields.io/badge/-Apache-D22128?logo=apache&logoColor=white)
![MySQL](https://img.shields.io/badge/-MySQL-4479A1?logo=mysql&logoColor=white)
![PHP](https://img.shields.io/badge/-PHP-777BB4?logo=php&logoColor=white)
![Tor](https://img.shields.io/badge/-Tor-7D4698?logo=tor-project&logoColor=white)

Автоматический скрипт для развертывания веб-сервера с поддержкой .onion адресов в Tor сети.

## 🔥 Особенности

- 🛠️ **Полностью автоматическая** установка всех компонентов
- 🌐 **Готовый .onion сайт** с PHPInfo
- 🔐 **Автогенерация** сложных паролей для MySQL
- 📊 **phpMyAdmin** последней версии с защитой
- ⚡ **Оптимизировано** для PHP 8.2
- 🚀 **Быстрая настройка** за 5 минут

## 📦 Устанавливаемые компоненты

| Компонент       | Версия       | Назначение          |
|----------------|-------------|--------------------|
| Apache         | 2.4.x       | Веб-сервер         |
| MySQL          | 8.0+        | База данных        |
| PHP            | 8.2         | Язык программирования |
| phpMyAdmin     | 5.2.1       | Управление БД      |
| Tor            | Последняя   | Анонимная сеть     |

## 🚀 Быстрый старт

```bash
# Скачать скрипт
wget https://raw.githubusercontent.com/ooocyberdev/install_tor_lamp/refs/heads/main/install_tor_lamp.sh
# Дать права на выполнение
chmod +x installer.sh
# Запустить установку
sudo ./installer.sh
```bash
Пример вывода:
==============================================
✅ Установка завершена!

🌐 Onion URL: http://your_unique_address.onion

🔑 Данные для подключения к MySQL:
   Хост: localhost
   Пользователь: root
   Пароль: XK8qD2wF5tR3yH9j
   Порт: 3306

📂 Корневая директория сайта: /var/www/tor-site
📊 phpMyAdmin: http://your_unique_address.onion/phpmyadmin
==============================================
