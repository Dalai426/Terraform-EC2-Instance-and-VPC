// the name of the provider should correspond to the name in the required_providers block
provider "aws" {
  region  = "us-east-1"
  profile = "terraform"
}

// it fetches data using the filter
// it loads the most recent AMI (Amzazon machine image)
// Data sections loads information frome external sources so that Terraform configurations can use it.
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}

variable "ssh_password" {
  type = string
}

variable "instance_name" {
  type    = string
  default = "EC2-Instance-1"
}
# -------------------------
# Private Cloud Network AWS
# -------------------------
variable "vpc_name" {
  type = string
}
// As determining the vpc, the virtual private cloyd network is created.
// As default, EC2 get default vpc from aws
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.19.0"

  name = var.vpc_name
  cidr = "10.0.0.0/16"

  azs = [
    "us-east-1a",
    "us-east-1b",
    "us-east-1c"
  ]

  // Other services in this VPC can communicate with EC2 by using private IP addresses.
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  // Now the EC2 instance is reachable from the internet by using public IP addresses.
  public_subnets  = ["10.0.101.0/24"]

  enable_dns_hostnames = true
}

# -------------------------
# Security Group AWS
# -------------------------
resource "aws_security_group" "ssh" {
  name        = "allow-ssh"
  description = "Allow SSH access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    # Replace with your public IP
    cidr_blocks = ["130.225.243.2/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

// Resource type : aws_instance, reource name : app_server
// The prefix of resource type should correspond to the provoder name
// As a resource block, Terraform defines a resource that Terraform manages it throught its lifecycle.
resource "aws_instance" "app_server" {
  // All data sources get id automatically
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = "dalai"

  vpc_security_group_ids = [
    aws_security_group.ssh.id
  ]

  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true

  tags = {
    Name = var.instance_name
  }

  // it is not infrastcuture as code, it is a just configuration.
  provisioner "remote-exec" {
    inline = [
      "sudo useradd -m -s /bin/bash dalai",
      "echo 'dalai:${var.ssh_password}' | sudo chpasswd",
      "sudo sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config",
      "sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config",
      "sudo systemctl restart ssh"
    ]
    // Using the connection, terraform executes my code
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("${path.module}/ssh/dalai.pem")
      host        = self.public_ip
    }
  }

  // The executor runs a command
  provisioner "local-exec" {
    command = "echo hello"
  }
}