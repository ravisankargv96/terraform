# Terraform Settings Block
terraform {
  required_version = ">= 1.8"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.26.0"
    }
  }
}

# Terraform Provider Block
provider "google" {
  credentials = file("../../GCPKey.json")
  project     = var.gcp_project
  region      = var.gcp_region1
}

#Input Variables
# GCP Project
variable "gcp_project" {
  description = "Project in which GCP Resources to be created"
  type        = string
  default     = "ravi-project-442017-c0"
}

# GCP Region
variable "gcp_region1" {
  description = "Region in which GCP Resource to be created"
  type        = string
  default     = "us-central1"
}

# GCP Compute Engine Machine Type
variable "machine_type" {
  description = "Compute Engine Machine Type"
  type        = string
  default     = "e2-small"
}

# Environment Variable
variable "environment" {
  description = "Environment Variable used as a prefix"
  type        = string
  default     = "dev"
}

# Business Division
variable "business_divison" {
  description = "Business Division in the large organization this Infrastructure belongs"
  type        = string
  default     = "sap"
}

# Define Local Values in Terraform
locals {
  owners      = var.business_divison
  environment = var.environment
  name        = "${var.business_divison}-${var.environment}"
  # name = "${local.owners}-${local.environment}"
  common_tags = {
    owners      = local.owners
    environment = local.environment
  }
}

# Resource: VPC
resource "google_compute_network" "myvpc" {
  name                    = "${local.name}-vpc"
  auto_create_subnetworks = false
}

# Resource: Subnet
resource "google_compute_subnetwork" "mysubnet" {
  name          = "${var.gcp_region1}-subnet"
  region        = var.gcp_region1
  ip_cidr_range = "10.128.0.0/20"
  network       = google_compute_network.myvpc.id
}

# Firewall Rule: SSH
resource "google_compute_firewall" "fw_ssh" {
  name = "${local.name}-fwrule-allow-ssh22"
  allow {
    ports    = ["22"]
    protocol = "tcp"
  }
  direction     = "INGRESS"
  network       = google_compute_network.myvpc.id
  priority      = 1000
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh-tag"]
}

# Firewall Rule: HTTP Port 80
resource "google_compute_firewall" "fw_http" {
  name = "${local.name}-fwrule-allow-http80"
  allow {
    ports    = ["80"]
    protocol = "tcp"
  }
  direction     = "INGRESS"
  network       = google_compute_network.myvpc.id
  priority      = 1000
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["webserver-tag"]
}

# Terraform Datasources
/*Datasource: Get a list of Google Compute zones that are UP in a region
*/
data "google_compute_zones" "available" {
  status = "UP"
}

# Output value
output "compute_zones" {
  description = "List of compute zones"
  value       = data.google_compute_zones.available.names
}

# Datasource: Get information about a Google Compute Image
data "google_compute_image" "my_image" {
  # Debian
  project = "debian-cloud"
  family  = "debian-12"

  # CentOs
  #project = "centos-cloud"  
  #family  = "centos-stream-9"

  # RedHat
  #project = "rhel-cloud" 
  #family  = "rhel-9"

  # Ubuntu
  #project = "ubuntu-os-cloud"
  #family  = "ubuntu-2004-lts"

  # Microsoft
  #project = "windows-cloud"
  #family  = "windows-2022"

  # Rocky Linux
  #project = "rocky-linux-cloud"
  #family  = "rocky-linux-8"
}

# Outputs
output "vmimage_project" {
  value = data.google_compute_image.my_image.project
}

output "vmimage_family" {
  value = data.google_compute_image.my_image.family
}

output "vmimage_name" {
  value = data.google_compute_image.my_image.name
}

output "vmimage_status" {
  value = data.google_compute_image.my_image.status
}

output "vmimage_id" {
  value = data.google_compute_image.my_image.id
}

output "vmimage_info" {
  value = {
    project   = data.google_compute_image.my_image.project
    family    = data.google_compute_image.my_image.family
    name      = data.google_compute_image.my_image.name
    image_id  = data.google_compute_image.my_image.image_id
    status    = data.google_compute_image.my_image.status
    id        = data.google_compute_image.my_image.id
    self_link = data.google_compute_image.my_image.self_link
  }
}

# Google Compute Engine: Regional Instance Template
resource "google_compute_region_instance_template" "myapp1" {

  name                 = "${local.name}-myapp1-template"
  description          = "This template is used to create MyApp1 server instances."
  tags                 = [tolist(google_compute_firewall.fw_ssh.target_tags)[0], tolist(google_compute_firewall.fw_http.target_tags)[0]]
  instance_description = "MyApp1 VM Instances"
  machine_type         = var.machine_type

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  # Create a new boot disk from an image
  disk {
    source_image = data.google_compute_image.my_image.self_link
    auto_delete  = true
    boot         = true
  }

  # Network Info
  network_interface {
    subnetwork = google_compute_subnetwork.mysubnet.id
    access_config {
      # Include this section to give the VM an external IP address
    }
  }

  # Install Webserver
  metadata_startup_script = file("${path.module}/app1-webserver-install.sh")

  labels = {
    environment = local.environment
  }

  metadata = {
    environment = local.environment
  }
}

# Resource Block: Create a Compute Engine VM instance
resource "google_compute_instance_from_template" "myapp1" {
  # Meta-Argument: for_each
  for_each                 = toset(data.google_compute_zones.available.names)
  name                     = "${local.name}-myapp1-vm-${each.key}"
  zone                     = each.key
  source_instance_template = google_compute_region_instance_template.myapp1.self_link
}

# Terraform Output values
# Output - For with list
output "instance_names" {
  description = "VM Instance Names"
  value       = [for instance in google_compute_instance_from_template.myapp1 : instance.name]
}

# Output - For Loop with Map
output "vm_instance_ids" {
  description = "VM Instances Names -> VM Instance IDs"
  value       = { for instance in google_compute_instance_from_template.myapp1 : instance.name => instance.instance_id }
}

output "vm_external_ips" {
  description = "VM Instance Names -> VM External IPs"
  value       = { for instance in google_compute_instance_from_template.myapp1 : instance.name => instance.network_interface.0.access_config.0.nat_ip }
}