# Setting AWS as a provider for the project
provider "aws" {
  region = var.aws_region
}

# Creating the S3 Bucket to host static website files
resource "aws_s3_bucket" "static_website_bucket" {
  bucket = var.s3_bucket_name
}

# S3 Block Public Access defaults configured to allow public read access
resource "aws_s3_bucket_public_access_block" "static_website_bucket_access" {
  bucket = aws_s3_bucket.static_website_bucket.id

  block_public_acls   = false
  block_public_policy = false
  ignore_public_acls  = false
  restrict_public_buckets = false
}

# Configuration to consider content as a static website
resource "aws_s3_bucket_website_configuration" "static_website_bucket_config" {
  bucket = aws_s3_bucket.static_website_bucket.id

  index_document {
    suffix = "webpage.html"
  }
}

# This S3 Bucket Policy grants public read access to all objects within it
resource "aws_s3_bucket_policy" "static_website_bucket_policy" {
  bucket = aws_s3_bucket.static_website_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.static_website_bucket.arn}/*"
      },
    ]
  })

  # Makes sure the Public Access defaults are configured for public read access
  depends_on = [aws_s3_bucket_public_access_block.static_website_bucket_access]
}

# Uploads the website files to the S3 Bucket
resource "aws_s3_object" "webpage_upload" {
  bucket       = aws_s3_bucket.static_website_bucket.id
  key          = "webpage.html"
  source       = "${path.module}/../website/webpage.html" # Path relative to main.tf
  content_type = "text/html"                               
  
  # Ensure the upload happens after the bucket and access permissions are ready
  depends_on = [aws_s3_bucket_policy.static_website_bucket_policy]
}
	


# Setting up a Content Delivery Network (CDN) for content caching and global S3 website serving over HTTPS 
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.static_website_bucket.bucket_regional_domain_name
    origin_id   = "S3-${var.s3_bucket_name}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for static S3 website"
  default_root_object = "webpage.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.s3_bucket_name}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Virtual Private Cloud (VPC) is created for hosting dynamic web servers
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Internet Gateway is created allowing communication between the VPC and the Internet.
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Subnet is created in the first Availability Zone (AZ 1) 
resource "aws_subnet" "public_subnet_az1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-az1"
  }
}

# Creates a second Public Subnet in a different AZ (multi-AZ for high availability)
resource "aws_subnet" "public_subnet_az2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-az2"
  }
}

# Public Route Table for traffic direction
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Associates the route table with the first public subnet
resource "aws_route_table_association" "public_subnet_az1_association" {
  subnet_id      = aws_subnet.public_subnet_az1.id
  route_table_id = aws_route_table.public_route_table.id
}

# Associates the route table with the second public subnet
resource "aws_route_table_association" "public_subnet_az2_association" {
  subnet_id      = aws_subnet.public_subnet_az2.id
  route_table_id = aws_route_table.public_route_table.id
}

# Security Group defines firewall rules for incoming and outbound traffic
resource "aws_security_group" "web_sg" {
  vpc_id      = aws_vpc.main.id
  name        = "${var.project_name}-web-sg"
  description = "Allow HTTP traffic from anywhere"

  # Allows incoming HTTP traffic from all IPs
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Allows all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}

# Defines the configuration for the EC2 instances in the Auto Scalling Group
resource "aws_launch_template" "web_lt" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = true
    security_groups = [aws_security_group.web_sg.id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y httpd
              sudo systemctl start httpd
              sudo systemctl enable httpd
              echo "<h1>Cloud Computing with AWS Test Webpage from $(hostname -f)</h1>" > /var/www/html/webpage.html
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-web-instance"
    }
  }
}

# Auto Scalling Group (ASG) ensures redundancy by managing web servers fleeting across two subnets
resource "aws_autoscaling_group" "web_asg" {
  name                 = "${var.project_name}-asg"
  vpc_zone_identifier  = [aws_subnet.public_subnet_az1.id, aws_subnet.public_subnet_az2.id]

  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }

  min_size             = var.asg_min_size
  max_size             = var.asg_max_size
  desired_capacity     = var.asg_desired_capacity

  health_check_type         = "EC2"
  health_check_grace_period = 300
}

# Defining ASG's "scale up" policy - it takes action after "cpu_high' alarm is triggered (add one instance)
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project_name}-scale-up"
  scaling_adjustment     = 1
  cooldown               = 300
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
}

# Defining ASG's "scale down" policy - it takes action after "cpu_low' alarm is triggered (remove one instance)
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project_name}-scale-down"
  scaling_adjustment     = -1
  cooldown               = 300
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
}

# CloudWatch alarm to trigger "scale up" policy
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "This alarm monitors EC2 CPU utilization"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
  }
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
}

# CloudWatch alarm to trigger "scale down" policy
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.project_name}-cpu-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 30
  alarm_description   = "This alarm monitors EC2 CPU utilization"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
  }
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]
}
