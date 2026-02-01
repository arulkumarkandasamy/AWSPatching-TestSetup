variable "env_name" { type = string }
variable "vpc_cidr" { type = string }
variable "subnet_cidr" { type = string }
variable "is_public" {
  type    = bool
  default = true
}
variable "master_tgw_id" {
  description = "Transit Gateway ID from the Master Account for spoke VPCs"
  type        = string
}