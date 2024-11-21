#!/bin/bash

###### 获取权限 ######
SCRIPT_PATH=$(readlink -f "$0")

if [ ! -x "$SCRIPT_PATH" ]; then
    echo "当前脚本未被赋予执行权限，正在添加执行权限..."
    chmod +x "$SCRIPT_PATH"
    echo "权限已添加，重新运行脚本..."
    exec "$SCRIPT_PATH" "$@"
    exit
fi

###### 基础参数 ######
DEFAULT_DOMAIN="techdrumstick.top"  # 默认域名
NGINX_CONTAINER_NAME="site1-nginx-1"  # Nginx Docker 容器名
WORK_DIR=$1  # 默认工作目录
if [ -z "$WORK_DIR" ]; then
  echo "未指定工作目录，请在调用脚本时提供工作目录路径。使用默认值"/var/www/site1""
  WORK_DIR="/var/www/site1"
fi
NGINX_CONF_PATH="$WORK_DIR/nginx.conf"  # Nginx 配置路径

###### 配置域名和 HTTPS ######
echo "配置域名和 SSL 证书功能"
read -p "请输入自定义域名 (例如 example.com): " DOMAIN
DOMAIN=${DOMAIN:-$DEFAULT_DOMAIN}  # 如果未输入，使用默认域名

read -p "是否启用 HTTPS？(y/n) (默认: y): " ENABLE_HTTPS
ENABLE_HTTPS=${ENABLE_HTTPS:-y}  # 如果未输入，默认启用 HTTPS

###### 修改 Nginx 配置 ######
echo "============================="
echo "1. 配置 Nginx"
echo "============================="

# 检查配置文件是否存在
if [ -f "$NGINX_CONF_PATH" ]; then
    echo "找到 Nginx 配置文件，开始更新 server_name..."

    # 使用 sed 替换 server_name 行
    sed -i "/^\s*server_name /c\    server_name $DOMAIN;" "$NGINX_CONF_PATH"

    echo "Nginx 配置中的 server_name 已更新为：$DOMAIN"
else
    echo "Nginx 配置文件 $NGINX_CONF_PATH 不存在，请检查路径。"
    exit 1
fi

# 提示用户设置 Cloudflare
echo "============================="
echo "2. 提示 Cloudflare 配置"
echo "============================="

SERVER_IP=$(curl -s ifconfig.me)
echo "请完成以下步骤以启用域名解析："
echo "1. 登录 Cloudflare 并进入 DNS 设置。"
echo "2. 添加或更新以下记录："
echo "   - A记录: $DOMAIN -> $SERVER_IP"
echo "3. 待全部配置完成后，再将 Proxy 状态改为 'Proxied' (橙色云图标)。"
read -n 1 -s -r -p "按任意键继续..."

###### 配置 HTTPS ######
if [ "$ENABLE_HTTPS" == "y" ]; then
    echo "============================="
    echo "3. 配置 HTTPS"
    echo "============================="

    echo "检查域名解析是否生效..."
    RESOLVED_IP=$(dig +short $DOMAIN | tail -n 1)
    if [[ "$RESOLVED_IP" != "$SERVER_IP" ]]; then
        echo "域名未解析到当前服务器 IP，请确认域名解析是否正确。"
        echo "当前域名解析到的 IP: $RESOLVED_IP"
        echo "服务器公网 IP: $SERVER_IP"
        exit 1
    else
        echo "域名解析正确，继续配置 HTTPS..."
    fi

    docker exec -it "$NGINX_CONTAINER_NAME" bash -c "
        apt update &&
        apt install -y certbot python3-certbot-nginx &&
        certbot --nginx -d $DOMAIN -d www.$DOMAIN
    "

    echo "HTTPS 配置完成！"
else
    echo "跳过 HTTPS 配置。"
fi

###### 检查并重新加载 Nginx 配置 ######
echo "============================="
echo "4. 检查并重新加载 Nginx 配置"
echo "============================="

docker exec $NGINX_CONTAINER_NAME nginx -t
if [ $? -ne 0 ]; then
    echo "Nginx 配置错误，请检查配置文件。"
    exit 1
fi

docker exec $NGINX_CONTAINER_NAME nginx -s reload
if [ $? -eq 0 ]; then
    echo "Nginx 服务已安全重启！"
else
    echo "Nginx 重启失败，请手动检查问题。"
    exit 1
fi

###### 配置完成提示 ######
echo "============================="
echo "5. 配置完成，测试站点访问"
echo "============================="

if [ "$ENABLE_HTTPS" == "y" ]; then
    echo "访问 WordPress: https://$DOMAIN 或 https://www.$DOMAIN"
else
    echo "访问 WordPress: http://$DOMAIN 或 http://www.$DOMAIN"
fi

echo "配置已完成！"
