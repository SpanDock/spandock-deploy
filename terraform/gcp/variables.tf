variable "project" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "Region, for example europe-west1 or us-central1."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone in the region, for example us-central1-a."
  type        = string
  default     = "us-central1-a"
}

variable "name" {
  description = "Name for the server."
  type        = string
  default     = "spandock-hub"
}

variable "machine_type" {
  description = "Machine type. e2-medium (2 vCPU, 4 GB) suits up to about 50 developers; size larger teams with https://www.spandock.com/requirements. For ARM (t2a-standard-2) set architecture = \"arm64\"."
  type        = string
  default     = "e2-medium"
}

variable "architecture" {
  description = "amd64 or arm64 (Tau T2A machine types)."
  type        = string
  default     = "amd64"
  validation {
    condition     = contains(["amd64", "arm64"], var.architecture)
    error_message = "architecture must be amd64 or arm64."
  }
}

variable "disk_gb" {
  description = "Boot disk size in GB (history is stored here)."
  type        = number
  default     = 30
}

variable "network" {
  description = "VPC network. The server needs outbound internet: an external IP (default) or Cloud NAT."
  type        = string
  default     = "default"
}

variable "external_ip" {
  description = "Give the server an ephemeral external IP for outbound traffic. Set false if the network has Cloud NAT."
  type        = bool
  default     = true
}

variable "spandock_version" {
  description = "Release tag to install, for example v0.14.0. \"latest\" installs the newest release."
  type        = string
  default     = "latest"
}

variable "join_code" {
  description = "To add a satellite: the single-use join code from the hub (Settings → Scaling → Add server). Empty: a new hub."
  type        = string
  default     = ""
  sensitive   = true
}

variable "labels" {
  description = "Extra labels."
  type        = map(string)
  default     = {}
}
