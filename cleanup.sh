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

# 检查是否以 root 身份运行
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 用户运行此脚本。"
  exit 1
fi

# 接收工作目录作为第一个参数
WORK_DIR=$1

if [ -z "$WORK_DIR" ]; then
  echo "未指定工作目录，请在调用脚本时提供工作目录路径。使用默认值"/var/www/site1""
  WORK_DIR="/var/www/site1"
fi


# 停止并移除所有相关容器
echo "停止并删除旧的 Docker 容器..."
docker compose -f "$WORK_DIR/docker-compose.yml" down || echo "没有运行的容器需要停止。"

# 删除未使用的卷
echo "删除未使用的 Docker 卷..."
docker volume prune -f || echo "没有未使用的卷需要删除。"

# 删除数据库卷（如果存在）
DB_VOLUME=$(docker volume ls -q | grep db_data)
if [ -n "$DB_VOLUME" ]; then
  echo "删除数据库卷: $DB_VOLUME"
  docker volume rm "$DB_VOLUME"
else
  echo "数据库卷已删除或不存在。"
fi

# 尝试卸载挂载点
echo "尝试卸载挂载点..."
if mount | grep "$WORK_DIR/wordpress" > /dev/null; then
  echo "卸载挂载点: $WORK_DIR/wordpress"
  umount -l "$WORK_DIR/wordpress" || echo "卸载失败，请检查挂载点。"
else
  echo "挂载点 $WORK_DIR/wordpress 未挂载，跳过卸载。"
fi

if mount | grep "$WORK_DIR/db_data" > /dev/null; then
  echo "卸载挂载点: $WORK_DIR/db_data"
  umount -l "$WORK_DIR/db_data" || echo "卸载失败，请检查挂载点。"
else
  echo "挂载点 $WORK_DIR/db_data 未挂载，跳过卸载。"
fi

# 修复目录权限
echo "检查并修复目录权限..."
chown -R root:root "$WORK_DIR/wordpress" "$WORK_DIR/db_data"
chmod -R 777 "$WORK_DIR/wordpress" "$WORK_DIR/db_data"
chattr -i "$WORK_DIR/wordpress" "$WORK_DIR/db_data" || echo "无法更改目录属性，可能未设置不可变属性。"

# 清理本地挂载目录
echo "清理本地挂载目录..."
rm -rf "$WORK_DIR/wordpress" || echo "清理 $WORK_DIR/wordpress 失败，请检查权限。"
rm -rf "$WORK_DIR/db_data" || echo "清理 $WORK_DIR/db_data 失败，请检查权限。"

# 检查清理是否成功
if [ "$(ls -A "$WORK_DIR/wordpress" 2>/dev/null)" ]; then
  echo "警告：目录 $WORK_DIR/wordpress 未能完全清理，请检查是否有占用或权限问题。"
else
  echo "目录 $WORK_DIR/wordpress 清理成功！"
fi

if [ "$(ls -A "$WORK_DIR/db_data" 2>/dev/null)" ]; then
  echo "警告：目录 $WORK_DIR/db_data 未能完全清理，请检查是否有占用或权限问题。"
else
  echo "目录 $WORK_DIR/db_data 清理成功！"
fi