# Указываем провайдер Docker
provider "docker" {
  host = var.docker_host
}

variable "docker_host" {
  description = "Docker host address"
  type        = string
}

# Создаем изолированную сеть
resource "docker_network" "isolated_network" {
  name = "isolated_network"
}

# Создаем контейнер front с двумя интерфейсами
resource "docker_container" "front" {
  image = "ubuntu:latest"  # Используем образ Ubuntu
  name  = "front"
  
  # Настройка внешнего интерфейса
  networks_advanced {
    name = "bridge"  # Внешняя сеть
    aliases = ["front_external"]
  }

  # Настройка изолированного интерфейса
  networks_advanced {
    name = docker_network.isolated_network.name
    aliases = ["front_internal"]
  }

  # Копируем публичный ключ в контейнер
  provisioner "file" {
    source      = "keys/id_rsa_terraform.pub"  # Путь к публичному ключу
    destination = "/root/.ssh/authorized_keys"  # Путь в контейнере
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
  image = "ubuntu:latest"  # Используем образ Ubuntu
  name  = "back"

  # Настройка изолированного интерфейса
  networks_advanced {
    name = docker_network.isolated_network.name
    aliases = ["back_internal"]
  }

  # Копируем публичный ключ в контейнер
  provisioner "file" {
    source      = "keys/id_rsa_terraform.pub"  # Путь к публичному ключу
    destination = "/root/.ssh/authorized_keys"  # Путь в контейнере
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
  image = "ubuntu:latest"  # Используем образ Ubuntu
  name  = "db"

  # Настройка изолированного интерфейса
  networks_advanced {
    name = docker_network.isolated_network.name
    aliases = ["db_internal"]
  }

  # Копируем публичный ключ в контейнер
  provisioner "file" {
    source      = "keys/id_rsa_terraform.pub"  # Путь к публичному ключу
    destination = "/root/.ssh/authorized_keys"  # Путь в контейнере
  }

  # Настраиваем права доступа к файлу authorized_keys
  provisioner "remote-exec" {
    inline = [
      "chmod 600 /root/.ssh/authorized_keys",
      "chown root:root /root/.ssh/authorized_keys"
    ]
  }

  # Добавляем дополнительный диск
  resource "docker_volume" "db_volume" {
    name = "db_data"
  }

  mount {
    source = docker_volume.db_volume.name
    target = "/var/lib/mysql"  # Путь, где будет храниться база данных
  }
}