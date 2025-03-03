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

# Создаем том для базы данных
resource "docker_volume" "db_volume" {
  name = "db_data"
}

# Создаем контейнер front с двумя интерфейсами
resource "docker_container" "front" {
  image = "ubuntu:latest"
  name  = "front"
  privileged = true  # Добавляем привилегии для использования tc

  # Настройка внешнего интерфейса
  networks_advanced {
    name    = "bridge"  # Внешняя сеть
  }

  # Настройка изолированного интерфейса
  networks_advanced {
    name    = docker_network.isolated_network.name
  }

  command = ["tail", "-f", "/dev/null"]  # Удерживаем контейнер активным

  # Устанавливаем SSH-сервер и настраиваем его через local-exec
  provisioner "local-exec" {
    command = <<EOT
      docker exec ${self.name} apt-get update
      docker exec ${self.name} apt-get install -y openssh-server iproute2 sudo python3-apt  # Устанавливаем необходимые пакеты
      docker exec ${self.name} mkdir -p /root/.ssh
      docker exec ${self.name} sh -c 'echo "${file("keys/id_rsa_terraform.pub")}" > /root/.ssh/authorized_keys'
      docker exec ${self.name} chmod 600 /root/.ssh/authorized_keys
      docker exec ${self.name} chown root:root /root/.ssh/authorized_keys

      # Запрещаем доступ по паролю и настраиваем SSH
      docker exec ${self.name} sh -c 'echo "PasswordAuthentication no" >> /etc/ssh/sshd_config'
      docker exec ${self.name} sh -c 'echo "PermitRootLogin prohibit-password" >> /etc/ssh/sshd_config'
      docker exec ${self.name} service ssh restart
      sleep 10  # Даем SSH-серверу время на перезапуск
    EOT
  }

  # Настройка подключения для provisioners
  connection {
    type     = "ssh"
    host     = self.network_data[0].ip_address  # Используем IP-адрес контейнера
    user     = "root"
    private_key = file("keys/id_rsa_terraform")
    timeout  = "2m"  # Увеличиваем таймаут для подключения
  }

  # Ограничение ширины канала (используем утилиту tc)
  provisioner "remote-exec" {
    inline = [
      "tc qdisc add dev eth0 root tbf rate 110mbit burst 32kbit latency 400ms"
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

  command = ["tail", "-f", "/dev/null"]  # Удерживаем контейнер активным

  # Устанавливаем SSH-сервер и настраиваем его через local-exec
  provisioner "local-exec" {
    command = <<EOT
      docker exec ${self.name} apt-get update
      docker exec ${self.name} apt-get install -y openssh-server sudo python3-apt  # Устанавливаем необходимые пакеты
      docker exec ${self.name} mkdir -p /root/.ssh
      docker exec ${self.name} sh -c 'echo "${file("keys/id_rsa_terraform.pub")}" > /root/.ssh/authorized_keys'
      docker exec ${self.name} chmod 600 /root/.ssh/authorized_keys
      docker exec ${self.name} chown root:root /root/.ssh/authorized_keys

      # Запрещаем доступ по паролю и настраиваем SSH
      docker exec ${self.name} sh -c 'echo "PasswordAuthentication no" >> /etc/ssh/sshd_config'
      docker exec ${self.name} sh -c 'echo "PermitRootLogin prohibit-password" >> /etc/ssh/sshd_config'
      docker exec ${self.name} service ssh restart
      sleep 10  # Даем SSH-серверу время на перезапуск
    EOT
  }

  # Настройка подключения для provisioners
  connection {
    type     = "ssh"
    host     = self.network_data[0].ip_address  # Используем IP-адрес контейнера
    user     = "root"
    private_key = file("keys/id_rsa_terraform")
    timeout  = "2m"  # Увеличиваем таймаут для подключения
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

  command = ["tail", "-f", "/dev/null"]  # Удерживаем контейнер активным

  # Устанавливаем SSH-сервер и настраиваем его через local-exec
  provisioner "local-exec" {
    command = <<EOT
      docker exec ${self.name} apt-get update
      docker exec ${self.name} apt-get install -y openssh-server sudo python3-apt  # Устанавливаем необходимые пакеты
      docker exec ${self.name} mkdir -p /root/.ssh
      docker exec ${self.name} sh -c 'echo "${file("keys/id_rsa_terraform.pub")}" > /root/.ssh/authorized_keys'
      docker exec ${self.name} chmod 600 /root/.ssh/authorized_keys
      docker exec ${self.name} chown root:root /root/.ssh/authorized_keys

      # Запрещаем доступ по паролю и настраиваем SSH
      docker exec ${self.name} sh -c 'echo "PasswordAuthentication no" >> /etc/ssh/sshd_config'
      docker exec ${self.name} sh -c 'echo "PermitRootLogin prohibit-password" >> /etc/ssh/sshd_config'
      docker exec ${self.name} service ssh restart
      sleep 10  # Даем SSH-серверу время на перезапуск
    EOT
  }

  # Настройка подключения для provisioners
  connection {
    type     = "ssh"
    host     = self.network_data[0].ip_address  # Используем IP-адрес контейнера
    user     = "root"
    private_key = file("keys/id_rsa_terraform")
    timeout  = "2m"  # Увеличиваем таймаут для подключения
  }

  # Используем том для хранения данных
  mounts {
    source = docker_volume.db_volume.name
    target = "/var/lib/mysql"  # Путь, где будет храниться база данных
    type   = "volume"
  }
}
