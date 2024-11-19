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

# 定义工作目录
SITE_NAME="site1"
BASE_DIR="/var/www"
WORK_DIR="$BASE_DIR/$SITE_NAME"

# 获取当前脚本的目录
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# 定义子脚本的路径
CLEANUP_SCRIPT="$SCRIPT_DIR/cleanup.sh"
INSTALL_DOCKER_SCRIPT="$SCRIPT_DIR/install_docker.sh"
SETUP_SCRIPT="$SCRIPT_DIR/setup.sh"
MODIFY_DB_SCRIPT="$SCRIPT_DIR/modify_db.sh" 

# 检查并运行子脚本函数
run_script() {
  local script_name="$1"

  if [ -f "$script_name" ]; then
    echo "运行脚本: $script_name"
    chmod +x "$script_name"  # 确保脚本具有执行权限
    "$script_name" "$WORK_DIR" || { echo "运行 $script_name 时出错，退出脚本。"; exit 1; }
    echo "$script_name 执行完成。"
  else
    echo "未找到脚本 $script_name，跳过此步骤。"
  fi
}

# 显示菜单
while true; do
  echo ""
  echo "请选择一个操作："
  echo "1. 卸载并重新安装 WordPress"
  echo "2. 清理 WordPress 自动安装文件"
  echo "3. 安装并配置 WordPress"
  echo "4. 安装 Docker"
  echo "5. 修改 WordPress 数据库信息" # 新增选项
  echo "6. 退出"
  read -p "请输入选项 [1-6]: " choice

  case $choice in
    1)
      echo "执行卸载并重新安装 WordPress..."
      run_script "$CLEANUP_SCRIPT"
      run_script "$SETUP_SCRIPT"
      ;;
    2)
      echo "执行清理 WordPress 自动安装文件..."
      run_script "$CLEANUP_SCRIPT"
      ;;
    3)
      echo "执行安装并配置 WordPress..."
      run_script "$SETUP_SCRIPT"
      ;;
    4)
      echo "执行安装 Docker..."
      run_script "$INSTALL_DOCKER_SCRIPT"
      ;;
    5)
      echo "修改 WordPress 数据库信息..."
      run_script "$MODIFY_DB_SCRIPT" # 调用新的子脚本
      ;;
    6)
      echo "退出脚本。"
      exit 0
      ;;
    *)
      echo "无效选项，请输入 1 到 6 之间的数字。"
      ;;
  esac
done