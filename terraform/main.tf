variable "docker_host" {
  description = "Docker host address"
  type        = string
}

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {
  host = var.docker_host
}

# Создаем изолированную сеть
resource "docker_network" "isolated_network" {
  name = "isolated_network"
}

# Создаем контейнер front с двумя интерфейсами
resource "docker_container" "front" {
  image = "ubuntu:latest"
  name  = "front"

  # Настройка внешнего интерфейса
  networks_advanced {
    name    = "bridge"  # Внешняя сеть
  }

  # Настройка изолированного интерфейса
  networks_advanced {
    name    = docker_network.isolated_network.name
  }

  command = ["tail", "-f", "/dev/null"]  # Удерживаем контейнер активным

  # Ограничение ширины канала (это не поддерживается напрямую в Docker, но можно использовать утилиту tc для настройки)
  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y iproute2",
      "tc qdisc add dev eth0 root tbf rate 110mbit burst 32kbit latency 400ms"
    ]
  }

  # Копируем публичный ключ в контейнер
  provisioner "file" {
    source      = "keys/id_rsa_terraform.pub"
    destination = "/root/.ssh/authorized_keys"
  }

  # Настраиваем права доступа к файлу authorized_keys
  provisioner "remote-exec" {
    inline = [
      "chmod 600 /root/.ssh/authorized_keys",
      "chown root:root /root/.ssh/authorized_keys"
    ]
  }
}

# Создаем контейнер back с одним интерфейсом
resource "docker_container" "back" {
  image = "ubuntu:latest"
  name  = "back"

  # Настройка изолированного интерфейса
  networks_advanced {
    name    = docker_network.isolated_network.name
    aliases = ["back_internal"]
  }

  # Копируем публичный ключ в контейнер
  provisioner "file" {
    source      = "keys/id_rsa_terraform.pub"
    destination = "/root/.ssh/authorized_keys"
  }

  # Настраиваем права доступа к файлу authorized_keys
  provisioner "remote-exec" {
    inline = [
      "chmod 600 /root/.ssh/authorized_keys",
      "chown root:root /root/.ssh/authorized_keys"
    ]
  }
}

# Создаем контейнер db с одним интерфейсом и дополнительным диском
resource "docker_container" "db" {
  image = "ubuntu:latest"
  name  = "db"

  # Настройка изолированного интерфейса
  networks_advanced {
    name    = docker_network.isolated_network.name
    aliases = ["db_internal"]
  }

  # Копируем публичный ключ в контейнер
  provisioner "file" {
    source      = "keys/id_rsa_terraform.pub"
    destination = "/root/.ssh/authorized_keys"
  }

  # Настраиваем права доступа к файлу authorized_keys
  provisioner "remote-exec" {
    inline = [
      "chmod 600 /root/.ssh/authorized_keys",
      "chown root:root /root/.ssh/authorized_keys"
    ]
  }

  # Используем том для хранения данных
  mounts {
    source = docker_volume.db_volume.name
    target = "/var/lib/mysql"  # Путь, где будет храниться база данных
    type   = "volume"
  }
}

# Создаем том для базы данных
resource "docker_volume" "db_volume" {
  name = "db_data"
}