output "instance_id" {
  description = "ID of the EC2 instance running SpanDock."
  value       = aws_instance.spandock.id
}

output "public_ip" {
  description = "Public IP of the instance (empty when the subnet assigns none)."
  value       = aws_instance.spandock.public_ip
}

output "activation" {
  description = "How to find the link that activates a new hub (approve it once on spandock.com)."
  value       = "Wait two or three minutes, then: aws ec2 get-console-output --region ${regex("^(.*[0-9])[a-z]+$", aws_instance.spandock.availability_zone)[0]} --instance-id ${aws_instance.spandock.id} --latest --output text | grep -o 'https://[^ ]*activate[^ ]*'"
}
