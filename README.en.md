# WordPress Docker Deployment Scripts

This repository contains a collection of shell scripts to set up, configure, and manage a Dockerized WordPress environment. These scripts help automate the installation and maintenance process for WordPress, MySQL, and related services.

---

## Scripts Overview

1. **`main.sh`**
   - Acts as a central management script.
   - Provides a menu to perform various tasks, such as installing WordPress, cleaning up, or modifying database settings.
   - Executes other scripts (`setup.sh`, `cleanup.sh`, `install_docker.sh`, `modify_db.sh`) based on user selection.

2. **`setup.sh`**
   - Automates the setup of a WordPress environment using Docker.
   - Configures necessary services, including Nginx, PHP, MySQL, and phpMyAdmin.
   - Generates required configuration files (`nginx.conf`, `php.ini`, `docker-compose.yml`).
   - Downloads and configures the latest version of WordPress.
   - Ensures all services are running and accessible.

3. **`cleanup.sh`**
   - Stops and removes existing Docker containers and volumes related to the WordPress environment.
   - Cleans up local directories and resets permissions.
   - Prepares the system for a fresh installation.

4. **`install_docker.sh`**
   - Installs Docker and Docker Compose on the host system.
   - Removes old Docker installations if present.
   - Configures Docker to start on system boot.

5. **`modify_db.sh`**
   - Allows users to update WordPress database credentials and configurations.
   - Updates the `wp-config.php` file with the new database details.
   - Modifies MySQL database and user settings inside the Docker container.

---

## Usage

Run `main.sh` to manage the WordPress environment via a menu:

```bash
./main.sh
```

Options include:

- Reinstall WordPress
- Clean up installation files
- Install Docker
- Modify database credentials

---

## Folder Structure

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

---

## License

This project is open-source and available under the MIT license.
