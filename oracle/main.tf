# A SpanDock server (hub or satellite) on Oracle Cloud: Ubuntu 24.04 on the Always Free Ampere shape
# by default, in its own network with no inbound rule (SpanDock only connects out). A few minutes
# after it boots, the instance's console connection or `journalctl -u spandock` shows the link that
# activates the server, once. https://www.spandock.com/docs/deploy

data "oci_identity_availability_domains" "all" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

locals {
  ad   = data.oci_identity_availability_domains.all.availability_domains[var.availability_domain_number - 1].name
  tags = { app = "spandock" }
  cloud_init = <<-YAML
    #cloud-config
    package_update: true
    packages:
      - curl
      - ca-certificates
    runcmd:
      - [bash, -c, "curl -fsSL --retry 3 https://www.spandock.com/deploy/install-server.sh | SPANDOCK_VERSION='${var.spandock_version}' SPANDOCK_JOIN_CODE='${var.join_code}' bash"]
  YAML
}

resource "oci_core_vcn" "spandock" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.name}-vcn"
  cidr_blocks    = ["10.71.0.0/24"]
  freeform_tags  = local.tags
}

resource "oci_core_internet_gateway" "spandock" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.spandock.id
  display_name   = "${var.name}-igw"
  freeform_tags  = local.tags
}

resource "oci_core_route_table" "spandock" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.spandock.id
  display_name   = "${var.name}-routes"
  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.spandock.id
  }
  freeform_tags = local.tags
}

resource "oci_core_security_list" "spandock" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.spandock.id
  display_name   = "${var.name}-outbound-only"
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }
  dynamic "ingress_security_rules" {
    for_each = var.allow_ssh_from == "" ? [] : [var.allow_ssh_from]
    content {
      source   = ingress_security_rules.value
      protocol = "6"
      tcp_options {
        min = 22
        max = 22
      }
    }
  }
  freeform_tags = local.tags
}

resource "oci_core_subnet" "spandock" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.spandock.id
  display_name      = "${var.name}-subnet"
  cidr_block        = "10.71.0.0/24"
  route_table_id    = oci_core_route_table.spandock.id
  security_list_ids = [oci_core_security_list.spandock.id]
  freeform_tags     = local.tags
}

resource "oci_core_instance" "spandock" {
  compartment_id      = var.compartment_ocid
  availability_domain = local.ad
  display_name        = var.name
  shape               = var.shape
  freeform_tags       = local.tags

  dynamic "shape_config" {
    for_each = length(regexall("Flex$", var.shape)) > 0 ? [1] : []
    content {
      ocpus         = var.ocpus
      memory_in_gbs = var.memory_gb
    }
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = var.disk_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.spandock.id
    assign_public_ip = true
  }

  metadata = merge(
    { user_data = base64encode(local.cloud_init) },
    var.ssh_public_key == "" ? {} : { ssh_authorized_keys = var.ssh_public_key },
  )

  lifecycle {
    ignore_changes = [source_details[0].source_id]
  }
}
