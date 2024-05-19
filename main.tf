terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
      version = "0.117.0"
    }
  }
  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    bucket     = "tf-state-bucket-mentor-ilya"
    region     = "ru-central1"
    key        = "issue1/lemp.tfstate"
    access_key = "YCAJEE13vMsch3ABCr77WjYya"
    secret_key = "YCO2UgefSRSJDqiLysKmNzuXFkoKOOg4p6zX7yn4"

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true # Необходимая опция Terraform для версии 1.6.1 и старше.
    skip_s3_checksum            = true # Необходимая опция при описании бэкенда для Terraform версии 1.6.3 и старше.
  }
}
# настройки подключения к облаку
provider "yandex" {
  token     = "y0_AgAAAAAN0OXrAATuwQAAAAEE0IbSAAAA4JYDOvNPM4-uKTzvKByd2SjLKA"
  cloud_id  = "b1garivv1r2su74hm7dm"
  folder_id = "b1gjgig2i53rj4q0n61b"
  zone      = "ru-central1-a"
}

# образ машинок
data "yandex_compute_image" "my_image" {
  family = "lemp"
}
# машинка №1
resource "yandex_compute_instance" "vm-1" {
  name = "terraform1"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.my_image.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  metadata = {
    ssh-keys = "/Users/ipleshachev/b537.pub"
  }
}
# машинка №2
resource "yandex_compute_instance" "vm-2" {
  name = "terraform2"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.my_image.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-2.id
    nat       = true
  }

  metadata = {
    ssh-keys = "/Users/ipleshachev/b537.pub"
  }
}
# сеть
resource "yandex_vpc_network" "network-1" {
  name = "network1"
}
# подсеть 1
resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}
# подсеть 2
resource "yandex_vpc_subnet" "subnet-2" {
  name           = "subnet2"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.11.0/24"]
}

# целевая группа балансера
resource "yandex_lb_target_group" "target_group" {
  name      = "my-target-group"
  region_id = "ru-central1"

  target {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    address   = yandex_compute_instance.vm-1.network_interface.0.ip_address
  }

  target {
    subnet_id = yandex_vpc_subnet.subnet-2.id
    address   = yandex_compute_instance.vm-2.network_interface.0.ip_address
  }
}

# балансер
resource "yandex_lb_network_load_balancer" "foo" {
  name = "my-network-load-balancer"

  listener {
    name = "my-listener"
    port = 8080
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.target_group.id

    healthcheck {
      name = "http"
      http_options {
        port = 8080
        path = "/ping"
      }
    }
  }
}
