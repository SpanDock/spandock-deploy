output "instance_id" {
  value = oci_core_instance.spandock.id
}

output "activate" {
  value = "Open the instance -> Resources -> Console connection (or SSH and run: journalctl -u spandock -f): the activation link appears a few minutes after boot."
}
