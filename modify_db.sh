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
# 默认值
default_db_name="wordpress"
default_db_user="wordpress"
default_db_password="wordpress"
mysql_root_password="root_password" # MySQL root 默认密码

# 提示用户输入旧的数据库信息
echo "请输入原来的数据库名称 (默认: $default_db_name):"
read old_db_name
old_db_name=${old_db_name:-$default_db_name}

echo "请输入原来的数据库用户名 (默认: $default_db_user):"
read old_db_user
old_db_user=${old_db_user:-$default_db_user}

echo "请输入原来的数据库密码 (默认: $default_db_password):"
read -s old_db_password
old_db_password=${old_db_password:-$default_db_password}

# 提示用户输入新的数据库信息
echo "请输入新的数据库名称:"
read new_db_name

echo "请输入新的数据库用户名:"
read new_db_user

echo "请输入新的数据库密码:"
read -s new_db_password

# 检查输入是否完整
if [[ -z "$new_db_name" || -z "$new_db_user" || -z "$new_db_password" ]]; then
  echo "新的数据库名称、用户名和密码不能为空！"
  exit 1
fi

# 修改数据库
echo "正在连接数据库并执行修改操作..."

docker exec -i $(docker ps -q --filter "ancestor=mysql:8.4.3") mysql -u root -p"$mysql_root_password" <<EOF
-- 创建新的数据库
CREATE DATABASE IF NOT EXISTS \`$new_db_name\`;

-- 创建新的用户并赋予权限
CREATE USER IF NOT EXISTS '$new_db_user'@'%' IDENTIFIED BY '$new_db_password';
GRANT ALL PRIVILEGES ON \`$new_db_name\`.* TO '$new_db_user'@'%';

-- 删除旧用户（可选）
DROP USER IF EXISTS '$old_db_user'@'%';

-- 刷新权限
FLUSH PRIVILEGES;
EOF

if [ $? -eq 0 ]; then
  echo "数据库名称、用户名和密码修改成功！"
  echo "新数据库名称: $new_db_name"
  echo "新用户名: $new_db_user"
else
  echo "数据库修改失败，请检查输入的原始信息是否正确。"
  exit 1
fi

# 接收工作目录作为第一个参数
WORK_DIR=$1

if [ -z "$WORK_DIR" ]; then
  echo "未指定工作目录，请在调用脚本时提供工作目录路径。使用默认值"/var/www/site1""
  WORK_DIR="/var/www/site1"
fi

# 修改 wp-config.php 文件
echo "正在更新 wp-config.php 配置..."
wp_config_path="$WORK_DIR/wordpress/wp-config.php"

if [ -f "$wp_config_path" ]; then
  sed -i "s/define( 'DB_NAME', .*/define( 'DB_NAME', '$new_db_name' );/" "$wp_config_path"
  sed -i "s/define( 'DB_USER', .*/define( 'DB_USER', '$new_db_user' );/" "$wp_config_path"
  sed -i "s/define( 'DB_PASSWORD', .*/define( 'DB_PASSWORD', '$new_db_password' );/" "$wp_config_path"
  echo "wp-config.php 配置已更新！"
else
  echo "未找到 wp-config.php 文件，请手动修改 WordPress 配置。"
fi