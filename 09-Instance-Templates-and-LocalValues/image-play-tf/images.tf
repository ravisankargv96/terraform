# Terraform Settings Block
terraform {
  required_version = ">= 1.8"
  required_providers {
    google = {
        source = "hashicorp/google"
        version = ">= 5.35.0"
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


data "google_compute_image" "my_image"{
    # Debian
    project = "debian-cloud"
    family = "debian-12"

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
output "id" {
    value = data.google_compute_image.my_image.id 
}

output "self_link" {
    value = data.google_compute_image.my_image.self_link
}

output "name" {
    value = data.google_compute_image.my_image.name 
}

output "family" {
    value = data.google_compute_image.my_image.family
}

output "image_id" {
    value = data.google_compute_image.my_image.image_id 
}

output "status" {
    value = data.google_compute_image.my_image.status 
}

output "licenses" {
    value = data.google_compute_image.my_image.licenses
}
