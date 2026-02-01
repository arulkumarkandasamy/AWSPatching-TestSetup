variable "org_id" {
  description = "The AWS Organization ID (o-xxxxx)"
  type        = string
}

variable "stakeholder_email" {
  description = "Email to receive patch reports and alerts"
  type        = string
}

variable "master_tgw_id" {
  description = "Transit Gateway ID from the Master Account for spoke VPCs"
  type        = string
}