# AWS Patching Test Setup

This directory contains Terraform code to set up a test environment for the AWS Patching solution. It provisions infrastructure across development and production environments to validate the patching automation workflows.

## Overview

The setup includes:
- **VPC Configuration**: Creates VPCs in spoke accounts.
- **Test Instances**: Provisions EC2 instances (Linux and Windows) with specific tags to trigger patching workflows.
- **Compliance Testing**: Supports creating "non-compliant" instances (older OS versions) to test remediation paths.

## Prerequisites

- Terraform installed (v1.0+)
- AWS Credentials configured with profiles:
  - `production-profile`
  - `development-profile`

## Project Structure

- `modules/vpc`: Module for creating VPC resources.
- `modules/test-ec2-instance`: Module for provisioning test EC2 instances.
- `provider.tf`: AWS provider configuration for multi-account setup.
- `variables.tf`: Input variables for the test setup.

## Usage

1. **Initialize Terraform:**
   ```bash
   terraform init
   ```

2. **Configure Variables:**
   Create a `terraform.tfvars` file with the required variables:
   ```hcl
   org_id            = "o-xxxxxxxxxx"
   stakeholder_email = "admin@example.com"
   master_tgw_id     = "tgw-xxxxxxxxxx"
   ```

3. **Deploy Infrastructure:**
   ```bash
   terraform apply
   ```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|:--------:|
| `org_id` | The AWS Organization ID. | `string` | Yes |
| `stakeholder_email` | Email to receive patch reports and alerts. | `string` | Yes |
| `master_tgw_id` | Transit Gateway ID from the Master Account for spoke VPCs. | `string` | Yes |
