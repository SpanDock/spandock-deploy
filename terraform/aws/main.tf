# A SpanDock server (hub or satellite) on EC2: Ubuntu 24.04, an encrypted gp3 disk, IMDSv2, and
# a security group with no inbound rule (SpanDock connects out; SSH only if you ask for it).

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-${var.architecture}-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_vpc" "default" {
  count   = var.subnet_id == "" ? 1 : 0
  default = true
}

data "aws_subnets" "default" {
  count = var.subnet_id == "" ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default[0].id]
  }
}

data "aws_subnet" "selected" {
  id = var.subnet_id != "" ? var.subnet_id : sort(data.aws_subnets.default[0].ids)[0]
}

locals {
  tags = merge({ Name = var.name, app = "spandock" }, var.tags)
}

resource "aws_security_group" "spandock" {
  name_prefix = "${var.name}-"
  description = "SpanDock server: outbound only"
  vpc_id      = data.aws_subnet.selected.vpc_id
  tags        = local.tags

  egress {
    description = "Outbound HTTPS and the encrypted tunnel"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = var.ssh_cidr == "" ? [] : [var.ssh_cidr]
    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "spandock" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.selected.id
  vpc_security_group_ids      = [aws_security_group.spandock.id]
  key_name                    = var.ssh_key_name == "" ? null : var.ssh_key_name
  associate_public_ip_address = true
  user_data_replace_on_change = false
  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    version   = var.spandock_version
    join_code = var.join_code
  })

  root_block_device {
    volume_type = "gp3"
    volume_size = var.disk_gb
    encrypted   = true
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags        = local.tags
  volume_tags = local.tags

  lifecycle {
    ignore_changes = [ami] # don't replace the server when Canonical publishes a newer image
  }
}
