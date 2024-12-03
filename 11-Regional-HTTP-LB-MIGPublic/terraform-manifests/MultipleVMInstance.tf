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
  default     = "e2-small" # change to micro if possible
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

# Resource: Regional Proxy-Only subnet (Required for Regional Application Load Balancer)
resource "google_compute_subnetwork" "regional_proxy_subnet" {
  name = "${var.gcp_region1}-regional-proxy-subnet"
  region = var.gcp_region1
  ip_cidr_range = "10.0.0.0/24"
  purpose = "REGIONAL_MANAGED_PROXY"
  network = google_compute_network.myvpc.id 
  role = "ACTIVE"
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

# Resource: Regional Health Check
resource "google_compute_region_health_check" "myapp1" {
  name  = "${local.name}-myapp1"
  check_interval_sec = 5
  timeout_sec = 5
  healthy_threshold = 2
  unhealthy_threshold = 3
  http_health_check {
    request_path = "/index.html"
    port = 80
  }
}

# Resource: Managed Instance Group
resource "google_compute_region_instance_group_manager" "myapp1"{
  name = "${local.name}-myapp1-mig"
  base_instance_name = "${local.name}-myapp1"
  region = var.gcp_region1
  distribution_policy_zones = data.google_compute_zones.available.names

  # Instance Template
  version {
    instance_template = google_compute_region_instance_template.myapp1.id
  }

  # Named Port
  named_port {
    name = "webserver"
    port = 80
  }

  # Autoscaling
  auto_healing_policies {
    health_check = google_compute_region_health_check.myapp1.id
    initial_delay_sec = 300
  }
}


# Resource: MIG Autoscaling
resource "google_compute_region_autoscaler" "myapp1" {
  name  = "${local.name}-myapp1-autoscaler"
  target = google_compute_region_instance_group_manager.myapp1.id 
  autoscaling_policy {
    max_replicas = 6
    min_replicas = 2
    cooldown_period = 60
    cpu_utilization {
      target = 0.9
    }
  } 
}

# Terraform Output Values
output "myapp1_mig_id" {
  value = google_compute_region_instance_group_manager.myapp1.id  
}

output "myapp1_mig_instance_group" {
  value = google_compute_region_instance_group_manager.myapp1.instance_group 
}

output "myapp1_mig_self_link"{
  value = google_compute_region_instance_group_manager.myapp1.self_link
}

output "myapp1_mig_status" {
  value = google_compute_region_instance_group_manager.myapp1.status 
}


# Resource: Reserver Regional Static IP Address
resource "google_compute_address" "mylb" {
  name = "${local.name}-mylb-regional-static-ip"
  region = var.gcp_region1  
}

# Resource: Regional Health Check
resource "google_compute_region_health_check" "mylb" {
  name = "${local.name}-mylb-myapp1-health-check"
  check_interval_sec = 5
  timeout_sec = 5
  healthy_threshold = 2
  unhealthy_threshold = 3
  http_health_check {
    request_path = "/index.html"
    port = 80
  }
}

# Resource: Regional Backend Service
resource "google_compute_region_backend_service" "mylb" {
  name = "${local.name}-myapp1-backend-service"
  protocol = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  health_checks = [google_compute_region_health_check.mylb.self_link]
  port_name = "webserver"
  backend {
    group = google_compute_region_instance_group_manager.myapp1.instance_group
    capacity_scaler = 1.0
    balancing_mode = "UTILIZATION"
  }
}

# Resource: Regional URL Map
resource "google_compute_region_url_map" "name" {
  name = "${local.name}-mylb-url-map"
  default_service = google_compute_region_backend_service.mylb.self_link  
}

# Resource: Regional HTTP Proxy
resource "google_compute_region_target_http_proxy" "mylb" {
  name = "${local.name}-mylb-http-proxy"
  url_map = google_compute_region_url_map.mylb.self_link
}

# Resource: Regional Forwarding Rule
resource "google_compute_forwarding_rule" "mylb" {
  name = "${local.name}-mylb-forwarding-rule"
  target = google_compute_region_target_http_proxy.mylb.self_link 
  port_range = "80"
  ip_protocol = "TCP"
  ip_address = google_compute_address.mylb.address 
  load_balancing_scheme = "EXTERNAL_MANAGED" # Creates new GCP LB (not classic)
  network = google_compute_network.myvpc.id
  depends_on = [ google_compute_subnetwork.regional_proxy_subnet ]
}

output "mylb_static_ip_address" {
  description = "The static IP address of the load balancer."
  value = google_compute_address.mylb.address 
}


output "mylb_backend_service_self_link"{
  description = "The self link of the backend service."
  value = google_compute_region_backend_service.mylb.self_link 
}

output "mylb_url_map_self_link" {
  description = "The self link of the URL map."
  value = google_compute_region_url_map.mylb.self_link 
}

output "mylb_target_http_proxy_self_link"{
  description = "The self link of the target HTTP proxy."
  value = google_compute_region_target_http_proxy.mylb.self_link 
}

output "mylb_forwarding_rule_ip_address" {
  description = "The IP address of the forwarding rule."
  value = google_compute_forwarding_rule.mylb.ip_address   
}