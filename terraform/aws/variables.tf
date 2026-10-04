variable "region" {
  description = "AWS region, for example eu-central-1 or us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name for the server and its resources."
  type        = string
  default     = "spandock-hub"
}

variable "instance_type" {
  description = "EC2 instance type. t3.medium (2 vCPU, 4 GB) suits up to about 50 developers; size larger teams with https://www.spandock.com/requirements. Use a Graviton type (t4g.medium) with architecture = \"arm64\"."
  type        = string
  default     = "t3.medium"
}

variable "architecture" {
  description = "amd64 for x86 instance types, arm64 for Graviton (t4g, m7g...)."
  type        = string
  default     = "amd64"
  validation {
    condition     = contains(["amd64", "arm64"], var.architecture)
    error_message = "architecture must be amd64 or arm64."
  }
}

variable "disk_gb" {
  description = "Root disk size in GB (history is stored here). See the calculator on https://www.spandock.com/requirements."
  type        = number
  default     = 30
}

variable "subnet_id" {
  description = "Subnet to use. Empty: the first subnet of the default VPC. The subnet needs outbound internet (a public IP or a NAT gateway)."
  type        = string
  default     = ""
}

variable "ssh_key_name" {
  description = "Existing EC2 key pair for SSH. Empty: no key (use the serial console or Session Manager)."
  type        = string
  default     = ""
}

variable "ssh_cidr" {
  description = "CIDR allowed to SSH in, for example 203.0.113.4/32. Empty: no inbound port at all (SpanDock doesn't need one)."
  type        = string
  default     = ""
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

variable "tags" {
  description = "Extra tags for every resource."
  type        = map(string)
  default     = {}
}
