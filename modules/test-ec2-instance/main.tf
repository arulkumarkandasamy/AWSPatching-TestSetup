terraform {
  required_providers {
    random = {
      source = "hashicorp/random"
    }
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

# --- IAM ROLE (SSM) ---
resource "aws_iam_role" "ssm_role" {
  name = "SSM-${var.os_type}-Role-${var.env_name}-${random_id.suffix.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "SSM-${var.os_type}-Profile-${var.env_name}-${random_id.suffix.hex}"
  role = aws_iam_role.ssm_role.name
}

# Add this policy to allow the EC2 to upload Scan Logs to the Central Bucket
resource "aws_iam_role_policy" "s3_logs_policy" {
  name = "Allow-SSM-Logs-Upload"
  role = aws_iam_role.ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetEncryptionConfiguration"
        ]
        # We need to allow access to the Central Bucket defined in your root variables
        Resource = [
            "arn:aws:s3:::ccs-org-patch-logs-mgmt-*/*", # Replace prefix with your actual bucket naming convention or pass as variable
            "arn:aws:s3:::ccs-org-patch-logs-mgmt-*"
        ]
      }
    ]
  })
}

# --- SECURITY GROUP ---
resource "aws_security_group" "sg" {
  name        = "patching-sg-${var.os_type}-${var.env_name}-${random_id.suffix.hex}"
  description = "Allow outbound HTTPS for SSM"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- AMI SELECTION LOGIC ---

# 1. Linux AMIs
# Compliant: Amazon Linux 2023 (Latest)
data "aws_ami" "linux_latest" {
  count       = var.os_type == "linux" && !var.is_non_compliant ? 1 : 0
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# Non-Compliant: Amazon Linux 2 (Older Generation)
# We use AL2 because AWS maintains it, but it is distinctly older than AL2023.
data "aws_ami" "linux_old" {
  count       = var.os_type == "linux" && var.is_non_compliant ? 1 : 0
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-*-x86_64-gp2"]
  }
}

# 2. Windows AMIs
# Compliant: Windows Server 2022 (Latest)
data "aws_ami" "windows_latest" {
  count       = var.os_type == "windows" && !var.is_non_compliant ? 1 : 0
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
}

# Non-Compliant: Windows Server 2019 (Older Generation)
data "aws_ami" "windows_old" {
  count       = var.os_type == "windows" && var.is_non_compliant ? 1 : 0
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base-*"]
  }
}

# --- INSTANCE ---
locals {
  # Dynamic AMI ID selection
  ami_id = var.os_type == "linux" ? (
      var.is_non_compliant ? data.aws_ami.linux_old[0].id : data.aws_ami.linux_latest[0].id
    ) : (
      var.is_non_compliant ? data.aws_ami.windows_old[0].id : data.aws_ami.windows_latest[0].id
    )
}

resource "aws_instance" "server" {
  ami                  = local.ami_id
  instance_type        = "t3.medium"
  subnet_id            = var.subnet_id
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
  vpc_security_group_ids = [aws_security_group.sg.id]

  # Add a root block device to ensure Windows has enough space
  root_block_device {
    volume_size = 40
    volume_type = "gp3"
  }

  tags = {
    Name        = "${var.env_name}-${var.os_type}-${var.is_non_compliant ? "NonCompliant" : "Compliant"}"
    PatchGroup  = var.patch_group_tag
    Compliance  = var.is_non_compliant ? "False" : "True"
  }
}