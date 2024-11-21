#!/bin/bash

###### 系统准备开始配置 ######

###### 获取权限 ######
# 获取脚本的绝对路径
SCRIPT_PATH=$(readlink -f "$0")

# 检查是否具有执行权限
if [ ! -x "$SCRIPT_PATH" ]; then
    echo "当前脚本未被赋予执行权限，正在添加执行权限..."
    chmod +x "$SCRIPT_PATH"
    echo "权限已添加，重新运行脚本..."
    exec "$SCRIPT_PATH" "$@"
    exit
fi
###### 获取权限 ######

# 是否使用默认配置
echo "是否本次安装都按照默认配置？(y/n)"
read -t 5 -p "请输入选项 [y/n] (默认: y): " default_choice

# 判断用户是否在 5 秒内输入
if [ $? -ne 0 ]; then
  echo "超时未选择，默认使用 y"
  default_choice="y"
else
  # 如果输入为空，设置为默认值
  default_choice=${default_choice:-y}
fi

# 输出选择
if [ "$default_choice" = "y" ]; then
  echo "选择了默认配置。"
else
  echo "选择了自定义配置。"
fi
default_choice=${default_choice:-y} # 如果未输入，默认为 y

# 根据默认配置设置变量
if [ "$default_choice" == "y" ]; then
    upgrade_choice="n"          # 默认不升级系统
    use_default="y"             # 默认使用默认管理员配置
else
    upgrade_choice=""           # 用户手动选择
    use_default=""              # 用户手动选择
fi

# 更新本地软件包索引
echo "正在更新本地软件包索引..."
sudo apt update || { echo "软件包索引更新失败，请检查网络连接。"; exit 1; }

# 提供升级系统的可选项
if [ -z "$upgrade_choice" ]; then
    read -p "是否需要升级已安装的软件包？(y/n) (默认: n): " upgrade_choice
    upgrade_choice=${upgrade_choice:-n}
fi

if [ "$upgrade_choice" == "y" ]; then
  echo "正在升级系统已安装的软件包，这可能需要一些时间..."
  sudo apt upgrade -y || { echo "系统升级失败，请手动检查问题。"; exit 1; }
else
  echo "跳过系统软件包升级。"
fi

# 必要软件列表
SOFTWARE_LIST=("curl" "git")  # 添加需要的软件到列表中

# 逐一检查并安装必要的软件
for software in "${SOFTWARE_LIST[@]}"; do
  echo "检查 $software 是否已安装..."
  if ! command -v $software &> /dev/null; then
    echo "$software 未安装，正在安装 $software..."
    sudo apt install -y $software || { echo "$software 安装失败，请手动检查问题。"; exit 1; }
    echo "$software 已成功安装！"
  else
    echo "$software 已安装，跳过安装步骤。"
  fi
done

# 安装 Docker 以及 Docker Compose
if [ -f "./install_docker.sh" ]; then
  echo "检测到 install_docker.sh 脚本，开始执行..."
  chmod +x ./install_docker.sh  # 确保脚本具有执行权限
  ./install_docker.sh || { echo "运行 install_docker.sh 脚本失败，请手动检查问题。"; exit 1; }
  echo "Docker 和 Docker Compose 安装完成！"
else
  echo "未找到 install_docker.sh 脚本，请将其放置在当前目录下并重新运行此脚本。"
  exit 1
fi

echo "必要软件已全部检查并安装完成！"

# 配置 Docker 服务（如果需要）
if systemctl is-active --quiet docker; then
  echo "Docker 服务正在运行。"
else
  echo "启动 Docker 服务..."
  sudo systemctl start docker || { echo "Docker 服务启动失败，请手动检查问题。"; exit 1; }
  sudo systemctl enable docker
  echo "Docker 服务已启动并设置为开机自启。"
fi

echo "系统已准备就绪！"

###### 系统准备完成 ######

# 1. 检查并停止宿主机上的 Nginx 服务
echo "检查宿主机是否运行 Nginx 服务..."
if systemctl is-active --quiet nginx; then
    echo "宿主机 Nginx 服务正在运行，停止服务..."
    sudo systemctl stop nginx
    echo "Nginx 服务已停止。"
    echo "禁止 Nginx 开机自启..."
    sudo systemctl disable nginx
else
    echo "宿主机未运行 Nginx 服务，无需停止。"
fi

# 设置工作目录

# 接收工作目录作为第一个参数
WORK_DIR=$1
DEFAULT_DOMAIN="techdrumstick.top" # 替换为默认域名
DOMAIN=$DEFAULT_DOMAIN
NGINX_CONTAINER_NAME="site1-nginx-1"    # Nginx Docker 容器名
ENABLE_HTTPS="y" # 默认启用 HTTPS

if [ -z "$WORK_DIR" ]; then
  echo "未指定工作目录，请在调用脚本时提供工作目录路径。使用默认值"/var/www/site1""
  SITE_NAME="site1"
  BASE_DIR="/var/www"
  WORK_DIR="$BASE_DIR/$SITE_NAME"
fi

# 确保基础目录存在
sudo mkdir -p "$WORK_DIR"

# 创建必要的子目录
echo "创建目录结构..."
sudo mkdir -p "$WORK_DIR/wordpress"
sudo mkdir -p "$WORK_DIR/db_data"

# 下载 WordPress
if [ ! -d "$WORK_DIR/wordpress/wp-admin" ]; then
  echo "下载 WordPress..."
  curl -o wordpress.tar.gz https://wordpress.org/latest.tar.gz
  sudo tar -xzf wordpress.tar.gz -C "$WORK_DIR/wordpress" --strip-components=1
  rm wordpress.tar.gz
else
  echo "WordPress 已存在，跳过下载。"
fi

# 设置文件权限
echo "设置 WordPress 文件权限..."
sudo chown -R www-data:www-data "$WORK_DIR/wordpress"
sudo chmod -R 755 "$WORK_DIR/wordpress"

# 创建 Nginx 配置文件
echo "生成 nginx.conf..."
cat > "$WORK_DIR/nginx.conf" <<EOL
server {
    listen 80;

    server_name $DOMAIN;  # 将 example.com 替换为您的域名或 IP
    root /var/www/html;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include fastcgi_params;
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL

# 创建 PHP 配置文件
echo "生成 php.ini..."
cat > "$WORK_DIR/php.ini" <<EOL
upload_max_filesize = 64M
post_max_size = 64M
memory_limit = 256M
max_execution_time = 300
EOL

# 创建 Dockerfile 为 PHP 安装 mysqli 扩展
echo "生成 Dockerfile..."
cat > "$WORK_DIR/Dockerfile" <<EOL
FROM php:8.0-fpm

# 安装 mysqli 扩展
RUN docker-php-ext-install mysqli pdo pdo_mysql && docker-php-ext-enable mysqli
EOL

# 创建 Docker Compose 配置文件
echo "生成 docker-compose.yml..."
cat > "$WORK_DIR/docker-compose.yml" <<EOL
version: '3.8'

services:
  nginx:
    image: nginx:latest
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - $WORK_DIR/nginx.conf:/etc/nginx/conf.d/default.conf
      - $WORK_DIR/wordpress:/var/www/html
    depends_on:
      - php

  php:
    build:
      context: $WORK_DIR
      dockerfile: Dockerfile

    volumes:
      - $WORK_DIR/wordpress:/var/www/html
      - $WORK_DIR/php.ini:/usr/local/etc/php/conf.d/php.ini

  db:
    image: mysql:8.4.3
    environment:
      MYSQL_ROOT_PASSWORD: root_password
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: wordpress
    volumes:
      - $WORK_DIR/db_data:/var/lib/mysql

  phpmyadmin:
    image: phpmyadmin:latest
    ports:
      - "8081:80"
    environment:
      PMA_HOST: db
      MYSQL_ROOT_PASSWORD: root_password
EOL

# 创建或重新生成 wp-config.php 文件
if [ -f "$WORK_DIR/wordpress/wp-config.php" ]; then
  echo "检测到 wp-config.php 文件已存在，正在删除旧文件..."
  sudo rm -f "$WORK_DIR/wordpress/wp-config.php" || { echo "删除 wp-config.php 文件失败，请检查权限。"; exit 1; }
fi

echo "生成新的 wp-config.php 文件..."
cp "$WORK_DIR/wordpress/wp-config-sample.php" "$WORK_DIR/wordpress/wp-config.php" || { echo "复制 wp-config-sample.php 失败，请检查文件是否存在。"; exit 1; }

# 替换数据库配置
sed -i "s/database_name_here/wordpress/" "$WORK_DIR/wordpress/wp-config.php"
sed -i "s/username_here/wordpress/" "$WORK_DIR/wordpress/wp-config.php"
sed -i "s/password_here/wordpress/" "$WORK_DIR/wordpress/wp-config.php"
sed -i "s/localhost/db/" "$WORK_DIR/wordpress/wp-config.php"

# 获取 WordPress 密钥和盐值
echo "从 WordPress 官方获取密钥和盐值..."
SALTS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
ESCAPED_SALTS=$(echo "$SALTS" | sed -e 's/[&/\]/\\&/g') # 转义特殊字符
if [ -z "$SALTS" ]; then
  echo "无法获取密钥和盐值，请检查网络连接。"
  exit 1
fi

# 使用 sed 逐行替换密钥和盐值
echo "正在清理和替换密钥和盐值..."
sed -i "s|define( 'AUTH_KEY'.*|$(echo "$ESCAPED_SALTS" | grep 'AUTH_KEY')|" "$WP_CONFIG"
sed -i "s|define( 'SECURE_AUTH_KEY'.*|$(echo "$ESCAPED_SALTS" | grep 'SECURE_AUTH_KEY')|" "$WP_CONFIG"
sed -i "s|define( 'LOGGED_IN_KEY'.*|$(echo "$ESCAPED_SALTS" | grep 'LOGGED_IN_KEY')|" "$WP_CONFIG"
sed -i "s|define( 'NONCE_KEY'.*|$(echo "$ESCAPED_SALTS" | grep 'NONCE_KEY')|" "$WP_CONFIG"
sed -i "s|define( 'AUTH_SALT'.*|$(echo "$ESCAPED_SALTS" | grep 'AUTH_SALT')|" "$WP_CONFIG"
sed -i "s|define( 'SECURE_AUTH_SALT'.*|$(echo "$ESCAPED_SALTS" | grep 'SECURE_AUTH_SALT')|" "$WP_CONFIG"
sed -i "s|define( 'LOGGED_IN_SALT'.*|$(echo "$ESCAPED_SALTS" | grep 'LOGGED_IN_SALT')|" "$WP_CONFIG"
sed -i "s|define( 'NONCE_SALT'.*|$(echo "$ESCAPED_SALTS" | grep 'NONCE_SALT')|" "$WP_CONFIG"

echo "wp-config.php 文件已成功配置！"

# 构建并启动 Docker 容器
echo "构建并启动 Docker 容器..."
docker compose -f "$WORK_DIR/docker-compose.yml" build php
docker compose -f "$WORK_DIR/docker-compose.yml" up -d

echo "检查服务状态..."
docker compose -f "$WORK_DIR/docker-compose.yml" ps

# 提问是否使用默认配置
echo "============================="
echo "是否按照默认配置运行？"
echo "默认配置："
echo "  - 域名: $DEFAULT_DOMAIN"
echo "  - 工作目录: $DEFAULT_WORK_DIR"
echo "  - 启用 HTTPS: 是"
read -t 5 -p "请输入 [y/n] (默认: y): " use_default

# 如果 5 秒未输入，默认选择 y
if [ $? -ne 0 ]; then
    echo "超时未选择，使用默认配置。"
    use_default="y"
fi

# 根据选择设置变量
if [ "$use_default" == "n" ]; then
    # 询问自定义域名
    read -p "请输入自定义域名 (例如 example.com): " DOMAIN
    DOMAIN=${DOMAIN:-$DEFAULT_DOMAIN} # 如果未输入，使用默认域名

    # 询问自定义工作目录
    read -p "请输入自定义工作目录 (默认: $DEFAULT_WORK_DIR): " WORK_DIR
    WORK_DIR=${WORK_DIR:-$DEFAULT_WORK_DIR} # 如果未输入，使用默认工作目录

    # 询问是否启用 HTTPS
    read -p "是否启用 HTTPS？(y/n) (默认: y): " ENABLE_HTTPS
    ENABLE_HTTPS=${ENABLE_HTTPS:-y} # 如果未输入，默认启用 HTTPS
else
    echo "使用默认配置..."
fi

echo "配置使用以下选项："
echo "  - 域名: $DOMAIN"
echo "  - 工作目录: $WORK_DIR"
echo "  - 启用 HTTPS: $([[ "$ENABLE_HTTPS" == "y" ]] && echo "是" || echo "否")"

echo "============================="
echo "2. 检查 Nginx 配置并重新加载"
echo "============================="

# 检查 Nginx 配置
docker exec "$NGINX_CONTAINER_NAME" nginx -t
if [ $? -ne 0 ]; then
    echo "Nginx 配置测试失败，请检查配置文件。"
    exit 1
else
    echo "Nginx 配置测试通过，重新加载服务..."
    docker exec "$NGINX_CONTAINER_NAME" nginx -s reload
fi

echo "============================="
echo "3. 提示 Cloudflare 配置"
echo "============================="

SERVER_IP=$(curl -s ifconfig.me)
echo "请完成以下步骤以启用域名解析："
echo "1. 登录 Cloudflare 并进入 DNS 设置。"
echo "2. 添加或更新以下记录："
echo "   - A记录: $DOMAIN -> $SERVER_IP"
echo "3. 待全部配置完成后，再将 Proxy 状态改为 'Proxied' (橙色云图标)。"
# 提示 Cloudflare 配置确认，等待用户输入任意键继续
read -n 1 -s -r -p "按任意键继续..."

if [ "$ENABLE_HTTPS" == "y" ]; then
    echo "============================="
    echo "4. 配置 HTTPS"
    echo "============================="

    echo "检查域名解析是否生效。ps: 此时需要将 Proxy 状态改为 'DNS Only'，否则无法解析到本服务器，在本shell全部配置完成后再设置为'Proxied' (橙色云图标)..."
    RESOLVED_IP=$(dig +short $DOMAIN | tail -n 1)
    if [[ "$RESOLVED_IP" != "$(curl -s ifconfig.me)" ]]; then
        echo "域名未解析到当前服务器 IP，请确认域名解析是否正确。"
        echo "当前域名解析到的 IP: $RESOLVED_IP"
        echo "服务器公网 IP: $(curl -s ifconfig.me)"
        exit 1
    else
        echo "域名解析正确，继续配置 HTTPS..."
    fi

    # 5. 进入 Nginx 容器并运行 Certbot
    echo "进入 Nginx 容器并配置 Certbot..."

    docker exec -it "$NGINX_CONTAINER_NAME" bash -c "
        apt update &&
        apt install -y certbot python3-certbot-nginx &&
        certbot --nginx -d $DOMAIN
    "

    echo "HTTPS 配置完成！"
else
    echo "跳过 HTTPS 配置。"
fi

echo "============================="
echo "检查 Nginx 配置..."
docker exec $NGINX_CONTAINER_NAME nginx -t
if [ $? -ne 0 ]; then
    echo "Nginx 配置错误，请检查配置文件。"
    exit 1
fi

echo "重新加载 Nginx 服务..."
docker exec $NGINX_CONTAINER_NAME nginx -s reload
if [ $? -eq 0 ]; then
    echo "Nginx 服务已安全重启！"
else
    echo "Nginx 重启失败，请手动检查问题。"
    exit 1
fi

echo "============================="
echo "5. 配置完成，测试站点访问"
echo "============================="

echo "你可以通过以下地址访问你的站点："

SERVER_IP=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

echo "所有服务已启动！"

echo "访问 phpMyAdmin: http://$SERVER_IP:8081"
echo "默认账号及密码："root" 和 "root_password""

echo "访问 WordPress: "
if [ "$ENABLE_HTTPS" == "y" ]; then
    echo "  - https://$DOMAIN 或 https://www.$DOMAIN"
else
    echo "  - http://$DOMAIN 或 http://www.$DOMAIN"
fi
echo "配置已完成！"