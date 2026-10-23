# Oracle Cloud Resource Manager fills tenancy_ocid, compartment_ocid and region in.

variable "tenancy_ocid" { type = string }
variable "compartment_ocid" { type = string }
variable "region" { type = string }

variable "name" {
  type    = string
  default = "spandock"
}

# The Always Free Ampere (ARM) shape: up to 4 OCPUs and 24 GB, enough for a large team. If Oracle
# reports "Out of host capacity", try another availability domain or VM.Standard.E5.Flex.
variable "shape" {
  type    = string
  default = "VM.Standard.A1.Flex"
}

variable "ocpus" {
  type    = number
  default = 2
}

variable "memory_gb" {
  type    = number
  default = 12
}

variable "disk_gb" {
  type    = number
  default = 50
}

variable "availability_domain_number" {
  type    = number
  default = 1
}

variable "ssh_public_key" {
  type        = string
  default     = ""
  description = "Optional: an SSH public key for the ubuntu user (SSH stays closed unless allow_ssh_from is set)."
}

variable "allow_ssh_from" {
  type    = string
  default = ""
}

variable "join_code" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Only for a satellite: a single-use join code from the hub."
}

variable "spandock_version" {
  type    = string
  default = ""
}
