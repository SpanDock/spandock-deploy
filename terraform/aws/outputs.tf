output "instance_id" {
  value = aws_instance.spandock.id
}

output "public_ip" {
  value = aws_instance.spandock.public_ip
}

output "activation" {
  description = "How to find the link that activates a new hub (approve it once on spandock.com)."
  value       = "Wait two or three minutes, then: aws ec2 get-console-output --region ${var.region} --instance-id ${aws_instance.spandock.id} --latest --output text | grep -o 'https://[^ ]*activate[^ ]*'"
}
