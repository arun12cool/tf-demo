
terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
      version = "2.15.0"
    }
  }
}
/*
provider "docker" {
  # Configuration options
}
*/
# Find the latest Ubuntu precise image.
resource "docker_image""ubuntu"{
  name = "ubuntu:precise"
  force_remove  = "true"
}

# Start a container
resource "docker_container" "ubuntu" {
  name  = "arun"
  image = docker_image.ubuntu.latest
  restart = "on-failure"
  publish_all_ports = true
  command = [
    "tail",
    "-f",
    "/dev/null"
  ]
  must_run = true
}


output "container_name" {
  value = docker_container.ubuntu.name
}

output "image_name" {
  value = docker_image.ubuntu.name
}

/*
Outputs:

container_name = "arun"
image_name = "ubuntu:precise"*/
