# Cloud Programming AWS Architecture (Free Tier focused)

This project provides a complete AWS cloud architecture solution for hosting a webpage with high availability, global distribution, and auto-scaling capabilities, specifically optimized for AWS Free Tier usage. The infrastructure is defined using Terraform (Infrastructure as Code) and includes all necessary components for a basic deployment.

## 📁 Project Structure

```

├── terraform/                         # Terraform Infrastructure as Code
│   ├── main.tf                        # Main Terraform configuration
│   ├── variables.tf                   # Variable definitions
    ├──terraform.tfvars                #           
│   └── outputs.tf                     # Output definitions
└── website/                           # Example website files
    ├── webpage.html                     # Webpage file
```

## 🚀 Quick Start: Installation and Tuning


### Prerequisites

1.  **AWS Account**: You need an active AWS account.
2.  **AWS CLI Configured**: Ensure you have the AWS Command Line Interface (CLI) installed and configured with credentials that have sufficient permissions to create and manage the resources defined in the Terraform files. You can configure it using `aws configure`.
3.  **Terraform Installed**: Terraform (version 0.12+) must be installed on your local machine. You can download it from the [Terraform website](https://www.terraform.io/downloads.html).

### Step 1: Clone the Repository


### Step 2: Configure Terraform Variables

You need to provide specific details for your AWS account and desired setup.

Open the `variables.tf` file. You will see the following variables, it's necessary to change some of the default parameters:

```
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-north-1"  # Replace with your AWS region
}

variable "project_name" {
  description = "Name of the project, used as a prefix for resources"
  type        = string
  default     = "web-app" # Can be replaced with other name
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for static website hosting"
  type        = string
  default     = "zhidilev-mikhail-static-web-page-2025" # Replace with the name of your S3 Bucket
}

variable "ami_id" {
  description = "AMI ID for the EC2 instances"
  type        = string
  default     = "ami-0abcdef1234567890" # Replace with a valid AMI ID for your region
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "Minimum number of EC2 instances in the Auto Scaling Group"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of EC2 instances in the Auto Scaling Group"
  type        = number
  default     = 3
}

variable "asg_desired_capacity" {
  description = "Desired number of EC2 instances in the Auto Scaling Group"
  type        = number
  default     = 1
}
```


**Setting up terraform.tfvars:**

Open a file named `terraform.tfvars` in the `terraform/` directory. This file will hold your specific values and will be automatically loaded by Terraform.

Default `terraform.tfvars` content:

```hcl
aws_region = "eu-north-1"
s3_bucket_name = "zhidilev-mikhail-static-web-page-2025"
ami_id = "ami-0c7d68785ec07306c"


instance_type = "t3.micro"
```
You need to change them to the ones you want to use for the project.


### Step 3: Initialize Terraform

From the `terraform/` directory, run:

```bash
.\terraform init
```

This command initializes the Terraform working directory, downloading the necessary AWS provider plugin.

### Step 4: Review the Plan

Before applying any changes, it's crucial to review what Terraform plans to do. Run:

```bash
.\terraform plan
```

This command shows you an execution plan, detailing all the AWS resources that will be created, modified, or destroyed. Review this output carefully to ensure it matches your expectations.

### Step 5: Apply the Infrastructure

If the plan looks correct, apply the changes to create your AWS infrastructure:

```bash
.\terraform apply
```

Terraform will prompt you to confirm the action. Type `yes` and press Enter to proceed.

### Step 6: Upload Website Files to S3

Once Terraform has successfully applied, your S3 bucket will be created. Now, upload the example website files to your S3 bucket. Make sure you are in the root project directory (one level above `terraform/`):

```bash
aws s3 sync website/ s3://<zhidilev-mikhail-static-web-page-2025>/ --acl public-read 
# Replace the bucket name with your own from tfvars
```


### Step 7: Access Your Website

After the Terraform apply is complete, Terraform will output the CloudFront distribution domain name. You can find this in the terminal output or by running:

```bash
.\terraform output cloudfront_domain_name
```

Copy the `cloudfront_domain_name` value and paste it into your web browser. You should see the default test webpage.

