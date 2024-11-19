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

set -e

# 检查 Docker 是否安装以及版本是否符合要求
check_docker() {
  if command -v docker &> /dev/null; then
    echo "检测到 Docker 已安装，版本信息："
    docker_version=$(docker --version | awk '{print $3}' | sed 's/,//')
    echo "当前 Docker 版本：$docker_version"
    return 0
  else
    echo "Docker 未安装。"
    return 1
  fi
}

# 检查 docker compose 插件是否安装以及版本是否符合要求
check_docker_compose() {
  if docker compose version &> /dev/null; then
    echo "检测到 Docker Compose 插件已安装，版本信息："
    docker_compose_version=$(docker compose version | awk '{print $4}' | sed 's/,//')
    echo "当前 Docker Compose 插件版本：$docker_compose_version"
    return 0
  else
    echo "Docker Compose 插件未安装。"
    return 1
  fi
}

# 检查是否需要安装 Docker
check_docker
docker_installed=$?

# 检查是否需要安装 Docker Compose 插件
check_docker_compose
docker_compose_installed=$?

if [ "$docker_installed" -eq 0 ] && [ "$docker_compose_installed" -eq 0 ]; then
  echo "Docker 和 Docker Compose 插件均已安装，跳过安装步骤。"
  exit 0
fi

echo "=== 移除旧版 Docker（如果存在） ==="
sudo apt-get remove -y docker docker-engine docker.io containerd runc || echo "旧版 Docker 不存在，跳过移除步骤。"

echo "=== 更新 APT 包索引 ==="
sudo apt update

echo "=== 安装必要的依赖工具 ==="
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

echo "=== 添加 Docker 官方 GPG 密钥 ==="
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "=== 添加 Docker 官方仓库 ==="
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "=== 更新包索引以包含 Docker 官方仓库 ==="
sudo apt update

echo "=== 安装 Docker 和 Docker Compose 插件 ==="
sudo apt install -y docker.io docker-compose-plugin

echo "=== 验证 Docker 安装 ==="
if command -v docker &> /dev/null; then
  echo "Docker 安装成功，版本信息："
  docker --version
else
  echo "Docker 安装失败，请检查！"
  exit 1
fi

echo "=== 验证 Docker Compose 插件安装 ==="
if docker compose version &> /dev/null; then
  echo "Docker Compose 插件安装成功，版本信息："
  docker compose version
else
  echo "Docker Compose 插件安装失败，请检查！"
  exit 1
fi

echo "=== 启动 Docker 服务并设置为开机自启 ==="
sudo systemctl start docker
sudo systemctl enable docker
echo "Docker 服务已启动并设置为开机自启。"

echo "=== 全部完成！Docker 和 Docker Compose 插件已成功安装并配置 ==="
