# WordPress Docker 部署脚本 (WordPress Docker Deployment Scripts)

本仓库包含一组脚本，用于通过 Docker 快速搭建、配置和管理 WordPress 环境。这些脚本可以自动化安装和维护 WordPress、MySQL 及相关服务。

This repository contains a collection of shell scripts to set up, configure, and manage a Dockerized WordPress environment. These scripts help automate the installation and maintenance process for WordPress, MySQL, and related services.

---

## 脚本简介 (Scripts Overview)

1. **`main.sh`**
   - 提供一个菜单，用于管理 WordPress 环境。
   - 根据用户选择执行其他脚本（如 `setup.sh`, `cleanup.sh`, `install_docker.sh`, `modify_db.sh`）。
   - 适合统一管理多个操作，如安装、清理、修改数据库等。

   - Acts as a central management script.
   - Provides a menu to perform various tasks, such as installing WordPress, cleaning up, or modifying database settings.
   - Executes other scripts (`setup.sh`, `cleanup.sh`, `install_docker.sh`, `modify_db.sh`) based on user selection.

2. **`setup.sh`**
   - 自动化部署 WordPress 环境，使用 Docker 配置必要的服务（Nginx、PHP、MySQL、phpMyAdmin）。
   - 生成相关配置文件（如 `nginx.conf`、`php.ini`、`docker-compose.yml`）。
   - 下载并配置最新版 WordPress。
   - 确保所有服务正常运行。

   - Automates the setup of a WordPress environment using Docker.
   - Configures necessary services, including Nginx, PHP, MySQL, and phpMyAdmin.
   - Generates required configuration files (`nginx.conf`, `php.ini`, `docker-compose.yml`).
   - Downloads and configures the latest version of WordPress.
   - Ensures all services are running and accessible.

3. **`cleanup.sh`**
   - 停止并移除现有的 Docker 容器和相关卷。
   - 清理本地目录并重置权限。
   - 为全新安装做好准备。

   - Stops and removes existing Docker containers and volumes related to the WordPress environment.
   - Cleans up local directories and resets permissions.
   - Prepares the system for a fresh installation.

4. **`install_docker.sh`**
   - 安装 Docker 和 Docker Compose。
   - 如果已有旧版本 Docker，自动卸载。
   - 配置 Docker 为开机自启动。

   - Installs Docker and Docker Compose on the host system.
   - Removes old Docker installations if present.
   - Configures Docker to start on system boot.

5. **`modify_db.sh`**
   - 用于更新 WordPress 数据库的连接配置。
   - 更新 `wp-config.php` 文件中的数据库信息。
   - 修改 MySQL 数据库及用户配置。

   - Allows users to update WordPress database credentials and configurations.
   - Updates the `wp-config.php` file with the new database details.
   - Modifies MySQL database and user settings inside the Docker container.

---

## 使用步骤 (Usage)

### 
运行 `main.sh`，通过菜单管理 WordPress 环境：

Run `main.sh` to manage the WordPress environment via a menu:
```bash
./main.sh

菜单选项包括：
- 卸载并重新安装 WordPress
- 清理安装文件
- 安装 Docker
- 修改数据库设置

Options include:
- Reinstall WordPress
- Clean up installation files
- Install Docker
- Modify database credentials


## 目录结构 (Folder Structure)

脚本假定以下目录结构用于 WordPress 部署：

The scripts assume the following directory structure for WordPress setup:
```
/var/www/site1/
  ├── wordpress/
  ├── db_data/
  ├── nginx.conf
  ├── php.ini
  ├── Dockerfile
  ├── docker-compose.yml
```

## 开源协议 (License)

本项目是开源的，遵循 MIT 协议。

This project is open-source and available under the MIT license.
```
