output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.s3_distribution.domain_name
}

output "s3_website_endpoint" {
  description = "The S3 static website endpoint"
  value       = aws_s3_bucket_website_configuration.static_website_bucket_config.website_endpoint
}


