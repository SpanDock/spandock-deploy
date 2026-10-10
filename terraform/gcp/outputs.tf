output "instance" {
  description = "Name of the Compute Engine instance running SpanDock."
  value       = google_compute_instance.spandock.name
}

output "activation" {
  description = "How to find the link that activates a new hub (approve it once on spandock.com)."
  value       = "Wait two or three minutes, then: gcloud compute instances get-serial-port-output ${google_compute_instance.spandock.name} --zone ${var.zone} --project ${google_compute_instance.spandock.project} | grep -o 'https://[^ ]*activate[^ ]*'"
}
