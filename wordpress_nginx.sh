#!/bin/bash

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

# 确保以 root 用户运行
if [ "$EUID" -ne 0 ]; then
    echo "请以 root 用户运行此脚本。"
    exit 1
fi

# 默认变量
DEFAULT_DOMAIN="techdrumstick.top" # 替换为默认域名
DEFAULT_WORK_DIR="/var/www/site1"
NGINX_CONTAINER_NAME="site1-nginx-1"    # Nginx Docker 容器名
# PHP_CONTAINER_NAME="site1-php-1"        # PHP Docker 容器名
ENABLE_HTTPS="y" # 默认启用 HTTPS
DOMAIN=$DEFAULT_DOMAIN
WORK_DIR=$DEFAULT_WORK_DIR


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

NGINX_CONF="$WORK_DIR/nginx.conf"

echo "============================="
echo "1. 创建 Nginx 配置文件"
echo "============================="

# 检查工作目录是否存在
mkdir -p "$WORK_DIR"

# 创建或覆盖 Nginx 配置文件
cat > "$NGINX_CONF" <<EOL

server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    root /var/www/html;
    index index.php index.html index.htm;

    # 配置静态文件缓存
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot|otf|ttc|mp4|webm|ogg|ogv|zip|gz|tgz|bz2|7z|xz|rar|pdf|doc|docx|ppt|pptx|xls|xlsx)$ {
        expires max;
        access_log off;
        add_header Cache-Control "public";
    }

    # 配置动态请求的处理
    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    # 处理 PHP 文件
    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass site1-php-1:9000;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }

    # 禁止访问隐藏文件
    location ~ /\. {
        deny all;
    }
}

EOL
echo "Nginx 配置文件已生成：$NGINX_CONF"

# 将配置文件挂载到 Nginx 容器内
echo "将配置挂载到 Nginx 容器..."
docker cp "$NGINX_CONF" "$NGINX_CONTAINER_NAME:/etc/nginx/conf.d/$DOMAIN.conf"

# 停止 Nginx 服务并容器
echo "停止 Nginx 容器..."
docker stop $NGINX_CONTAINER_NAME

# 确保容器已停止
echo "等待 5 秒确保容器停止..."
sleep 5

# 启动 Nginx 容器
echo "启动 Nginx 容器..."
docker start $NGINX_CONTAINER_NAME

# 删除默认配置
echo "删除 default 配置文件..."
docker exec $NGINX_CONTAINER_NAME rm -f /etc/nginx/conf.d/default.conf

# 重启 Nginx 服务
echo "重新加载 Nginx 配置..."
docker exec $NGINX_CONTAINER_NAME nginx -t
docker exec $NGINX_CONTAINER_NAME nginx -s reload

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
echo "   - A记录: www.$DOMAIN -> $SERVER_IP"
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

    echo "安装 Certbot 并获取 Let’s Encrypt 证书..."
    apt update
    apt install -y certbot python3-certbot-nginx
    certbot --nginx -d $DOMAIN -d www.$DOMAIN
    echo "HTTPS 配置完成！"
else
    echo "跳过 HTTPS 配置。"
fi

echo "============================="
echo "5. 配置完成，测试站点访问"
echo "============================="

echo "你可以通过以下地址访问你的站点："

if [ "$ENABLE_HTTPS" == "y" ]; then
    echo "  - https://$DOMAIN 或 https://www.$DOMAIN"
else
    echo "  - http://$DOMAIN 或 http://www.$DOMAIN"
fi
echo "配置已完成！"