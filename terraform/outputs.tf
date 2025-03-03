output "back_container_ip" {
  description = "IP-адрес контейнера back"
  value       = docker_container.back.network_data[0].ip_address
}

output "db_container_ip" {
  description = "IP-адрес контейнера db"
  value       = docker_container.db.network_data[0].ip_address
}

output "front_container_ips" {
  description = "IP-адреса контейнера front"
  value = {
    bridge           = docker_container.front.network_data[0].ip_address
    isolated_network = docker_container.front.network_data[1].ip_address
  }
}
