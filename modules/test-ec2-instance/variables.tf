variable "env_name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_id" { type = string }
variable "patch_group_tag" { type = string }
variable "os_type" { 
  type    = string
  default = "linux" 
  validation {
    condition     = contains(["linux", "windows"], var.os_type)
    error_message = "os_type must be 'linux' or 'windows'."
  }
}
variable "is_non_compliant" {
  type    = bool
  default = false
  description = "If true, provision an older OS version (AL2 or Win2019)."
}
