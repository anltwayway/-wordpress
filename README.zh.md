# WordPress Docker 部署脚本

本仓库包含一组脚本，用于通过 Docker 快速搭建、配置和管理 WordPress 环境。这些脚本可以自动化安装和维护 WordPress、MySQL 及相关服务。

---

## 脚本简介

1. **`main.sh`**
   - 提供一个菜单，用于管理 WordPress 环境。
   - 根据用户选择执行其他脚本（如 `setup.sh`, `cleanup.sh`, `install_docker.sh`, `modify_db.sh`）。
   - 适合统一管理多个操作，如安装、清理、修改数据库等。

2. **`setup.sh`**
   - 自动化部署 WordPress 环境，使用 Docker 配置必要的服务（Nginx、PHP、MySQL、phpMyAdmin）。
   - 生成相关配置文件（如 `nginx.conf`、`php.ini`、`docker-compose.yml`）。
   - 下载并配置最新版 WordPress。
   - 确保所有服务正常运行。

3. **`cleanup.sh`**
   - 停止并移除现有的 Docker 容器和相关卷。
   - 清理本地目录并重置权限。
   - 为全新安装做好准备。

4. **`install_docker.sh`**
   - 安装 Docker 和 Docker Compose。
   - 如果已有旧版本 Docker，自动卸载。
   - 配置 Docker 为开机自启动。

5. **`modify_db.sh`**
   - 用于更新 WordPress 数据库的连接配置。
   - 更新 `wp-config.php` 文件中的数据库信息。
   - 修改 MySQL 数据库及用户配置。

---

## 使用步骤

运行 `main.sh`，通过菜单管理 WordPress 环境：

```bash
./main.sh
```

菜单选项包括：

- 卸载并重新安装 WordPress
- 清理安装文件
- 安装 Docker
- 修改数据库设置

---

## 目录结构

脚本假定以下目录结构用于 WordPress 部署：

```
/var/www/site1/
  ├── wordpress/
  ├── db_data/
  ├── nginx.conf
  ├── php.ini
  ├── Dockerfile
  ├── docker-compose.yml
```

---

## 开源协议

本项目是开源的，遵循 MIT 协议。
