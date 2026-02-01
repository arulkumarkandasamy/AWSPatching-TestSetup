# ================= PRODUCTION (Public / Compliant) =================

# module "prod_vpc" {
#   source = "./modules/vpc"
#   # Pass the Production Provider
#   providers = { aws = aws.production }

#   env_name    = "prod"
#   vpc_cidr    = "10.10.0.0/16"
#   subnet_cidr = "10.10.1.0/24"
#   is_public   = true  # <--- Has Internet Gateway
# }

# module "prod_ec2_windows" {
#   source = "./modules/test-ec2-instance"
#   providers = { aws = aws.production }

#   env_name         = "prod-win"
#   vpc_id           = module.prod_vpc.vpc_id
#   subnet_id        = module.prod_vpc.subnet_id
#   patch_group_tag  = "Production"
#   os_type          = "windows"
#   is_non_compliant = false
# }

# ================= DEVELOPMENT (Private / Non-Compliant) =================

module "dev_vpc" {
  source = "./modules/vpc"
  # Pass the Development Provider
  providers = { aws = aws.development }

  env_name    = "dev"
  vpc_cidr    = "10.20.0.0/16"
  subnet_cidr = "10.20.1.0/24"
  is_public   = false # <--- NO Internet Gateway (Patching will fail)
  master_tgw_id = var.master_tgw_id
}

module "dev_ec2_windows" {
  source = "./modules/test-ec2-instance"
  providers = { aws = aws.development }

  env_name         = "dev-win"
  vpc_id           = module.dev_vpc.vpc_id
  subnet_id        = module.dev_vpc.subnet_id
  patch_group_tag  = "Development"
  os_type          = "windows"
  is_non_compliant = true
}


# =============================================================================
# 3. DEV ACCOUNT CONNECTIVITY (Spoke -> Hub)
# =============================================================================

# 1. Find the Shared TGW (Assuming it's shared via RAM)
# data "aws_ec2_transit_gateway" "hub_tgw" {
#   provider = aws.development
#   filter {
#     name   = "tag:Name"
#     values = ["CCS-Org-TGW"] # Must match tag in Master
#   }
# }

locals {
  # REPLACE THIS with your actual TGW ID from the Master Account
  master_tgw_id = var.master_tgw_id 
}

# Attach Dev VPC to TGW (Using Direct Reference)
# resource "aws_ec2_transit_gateway_vpc_attachment" "dev_attach" {
#   provider           = aws.development
#   subnet_ids         = [module.dev_vpc.subnet_id]

#   # FIX: Use the output from the central_reporting module
#   transit_gateway_id = local.master_tgw_id

#   vpc_id             = module.dev_vpc.vpc_id
# }

# Add Route to Dev Route Table
# resource "aws_route" "dev_to_hub" {
#   provider               = aws.development
#   route_table_id         = module.dev_vpc.route_table_id # Or output from VPC module
#   destination_cidr_block = "10.100.0.0/16" 

#   # FIX: Use the output here too
#   transit_gateway_id     = local.master_tgw_id

#   depends_on             = [aws_ec2_transit_gateway_vpc_attachment.dev_attach]
# }
