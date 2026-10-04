# A SpanDock server (hub or satellite) on Compute Engine: Ubuntu 24.04, Shielded VM, and no
# firewall rule (SpanDock connects out; nothing needs to reach it).

resource "google_compute_instance" "spandock" {
  name         = var.name
  machine_type = var.machine_type
  zone         = var.zone
  labels       = merge({ app = "spandock" }, var.labels)

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-${var.architecture}"
      size  = var.disk_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = var.network
    dynamic "access_config" {
      for_each = var.external_ip ? [1] : []
      content {}
    }
  }

  metadata = {
    user-data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
      version   = var.spandock_version
      join_code = var.join_code
    })
    serial-port-logging-enable = "TRUE"
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  lifecycle {
    ignore_changes = [metadata["user-data"], boot_disk[0].initialize_params[0].image]
  }
}
