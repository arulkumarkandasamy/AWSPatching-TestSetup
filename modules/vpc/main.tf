terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# 1. VPC (Always created)
resource "aws_vpc" "spoke_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "vpc-${var.env_name}" }
}

# 2. Internet Gateway (ONLY if is_public = true)
resource "aws_internet_gateway" "spoke_igw" {
  count  = var.is_public ? 1 : 0
  vpc_id = aws_vpc.spoke_vpc.id
  tags   = { Name = "igw-${var.env_name}" }
}

# 3. Subnet (Generic)
resource "aws_subnet" "spoke_subnet" {
  vpc_id                  = aws_vpc.spoke_vpc.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = var.is_public # True for Prod, False for Dev
  availability_zone       = "us-east-1a"
  tags = { Name = "subnet-${var.env_name}" }
}

locals {
  # REPLACE THIS with your actual TGW ID from the Master Account
  master_tgw_id = var.master_tgw_id
}

resource "aws_ec2_transit_gateway_vpc_attachment" "spoke_tgw_attachment" {
  subnet_ids         = [aws_subnet.spoke_subnet.id]
  transit_gateway_id = local.master_tgw_id
  vpc_id             = aws_vpc.spoke_vpc.id
}

# 4. Route Table
resource "aws_route_table" "spoke_rt" {
  count       = var.is_public ? 0 : 1
  vpc_id = aws_vpc.spoke_vpc.id

  # Route to Master VPC via TGW
  route {
    # CHANGE THIS from "10.0.0.0/16" to "10.0.0.0/8"
    # This covers 10.0.x.x, 10.20.x.x, 10.100.x.x, etc.
    cidr_block         = "10.0.0.0/8" 
    transit_gateway_id = local.master_tgw_id

    # cidr_block         = "0.0.0.0/0" 
    # transit_gateway_id = local.master_tgw_id
  }

  tags   = { Name = "rt-${var.env_name}" }
}

resource "aws_route_table_association" "spoke_rt_assoc" {
  count = var.is_public ? 0 : 1
  subnet_id      = aws_subnet.spoke_subnet.id
  route_table_id = aws_route_table.spoke_rt[0].id
}

# 5. Route to Internet (ONLY if is_public = true)
resource "aws_route" "spoke_public_internet" {
  count                  = var.is_public ? 1 : 0
  route_table_id         = aws_route_table.spoke_rt[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.spoke_igw[0].id
}

resource "aws_route" "spoke_internet_via_tgw" {
  count                  = var.is_public ? 0 : 1
  route_table_id         = aws_route_table.spoke_rt[0].id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = local.master_tgw_id
}

# 6. VPC Endpoints (ONLY if is_public = false)
# We need these for SSM to work in Dev so we can even TRY to patch
resource "aws_security_group" "spoke_vpce_sg" {
  count       = var.is_public ? 0 : 1
  name        = "vpce-sg-${var.env_name}"
  description = "Allow TLS for VPC Endpoints"
  vpc_id      = aws_vpc.spoke_vpc.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
}

resource "aws_vpc_endpoint" "ssm" {
  for_each          = var.is_public ? [] : toset(["ssm", "ec2messages", "ssmmessages"])
  vpc_id            = aws_vpc.spoke_vpc.id
  service_name      = "com.amazonaws.us-east-1.${each.key}"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.spoke_subnet.id]
  security_group_ids = [aws_security_group.spoke_vpce_sg[0].id]
  private_dns_enabled = true
}

resource "aws_route_table" "spoke_public" {
  vpc_id = aws_vpc.spoke_vpc.id
  
  # Route to Internet (For WSUS to get updates from Microsoft)
  route {
    cidr_block = "0.0.0.0/0"
    transit_gateway_id = local.master_tgw_id
  }

  # Route to Development Spoke (Return Traffic)
  route {
    cidr_block = "10.0.0.0/8" # Your Dev VPC CIDR
    transit_gateway_id = local.master_tgw_id
  }
  
  tags = { Name = "CCS-Spoke-Public-RT" }
}


# 1. Create the dedicated Spoke Route Table
# resource "aws_ec2_transit_gateway_route_table" "spoke_rt" {
#   transit_gateway_id = data.aws_ec2_transit_gateway.master_tgw.id
  
#   tags = {
#     Name = "CCS-Org-TGW-Spoke-RT" # Name it clearly
#   }
# }

# 2. Associate your Dev VPC Attachment with this new table
# (This ensures the Dev VPC uses THIS table's rules)
# resource "aws_ec2_transit_gateway_route_table_association" "dev_association" {
#   transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.example.id
#   transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke_rt.id
# }

# 3. Add the Route: Send all Spoke traffic to the Hub
# resource "aws_ec2_transit_gateway_route" "spoke_to_hub_internet" {
#   destination_cidr_block         = "0.0.0.0/0"
#   transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke_rt.id
#   transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub_attachment.id
# }