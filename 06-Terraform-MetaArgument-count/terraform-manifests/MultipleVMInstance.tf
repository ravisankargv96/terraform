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

# Resource: VPC
resource "google_compute_network" "myvpc" {
  name                    = "vpc1"
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
  name = "fwrule-allow-ssh22"
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
  name = "fwrule-allow-http80"
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

# Resource Block: Create a Compute Engine Instance
resource "google_compute_instance" "myapp1" {
  # Meta-Argument: count
  count        = 2
  name         = "myapp1-vm-${count.index}"
  machine_type = var.machine_type
  zone         = "${var.gcp_region1}-a"
  tags         = [tolist(google_compute_firewall.fw_ssh.target_tags)[0], tolist(google_compute_firewall.fw_http.target_tags)[0]]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  # Install Webserver
  metadata_startup_script = file("${path.module}/app1-webserver-install.sh")
  network_interface {
    subnetwork = google_compute_subnetwork.mysubnet.id
    access_config {
      # Include this section to give the VM an external IP address
    }
  }
}


# Output Values
# Terraform Output Values
/* Concepts Covered
1. For Loop with List
2. For Loop with Map
3. For Loop with Map Advanced
4. Legacy Splat Operator (latest) - Returns List
5. Latest Generalized Splat Operator - Returns the List
*/

# Get each list item separately
output "vm_name_0" {
  description = "VM Name"
  value       = google_compute_instance.myapp1[0].name
}

# Get each list item separately
output "vm_name_1" {
  description = "VM Name"
  value       = google_compute_instance.myapp1[1].name
}

# Output - For Loop with List
output "for_output_list" {
  description = "For Loop with List"
  value       = [for instance in google_compute_instance.myapp1 : instance.name]
}

# Output - For Loop with Map
output "for_output_map1" {
  description = "For Loop with Map"
  value       = { for instance in google_compute_instance.myapp1 : instance.name => instance.instance_id }
}

# Output - For Loop with Map Advancedf
output "for_output_map3" {
  description = "For Loop with Map - Advanced (Instance Name and Instance ID)"
  value       = { for c, instance in google_compute_instance.myapp1 : instance.name => instance.instance_id }
}

# VM External IPs
output "vm_external_ips" {
  description = "For Loop with Map - Advanced"
  value       = { for c, instance in google_compute_instance.myapp1 : c => instance.network_interface.0.access_config.0.nat_ip }
}

# Output Legacy Splat Operator (Legacy) - Returns the List
output "legacy_splat_instance" {
  description = "Legacy Splat Operator"
  value       = google_compute_instance.myapp1.*.name
}

# Output Latest Generalized Splat Operator - Returns the List
output "latest_splat_instance" {
  description = "Generalized latest Splat Operator"
  value       = google_compute_instance.myapp1[*].name
}