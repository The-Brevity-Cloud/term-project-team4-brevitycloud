output "s3_bucket_id" {
  description = "ID of the S3 bucket"
  value       = aws_s3_bucket.webpage_content.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.webpage_content.arn
}

output "s3_data_source_id" {
  description = "ID of the Kendra S3 data source"
  value       = aws_kendra_data_source.s3_data_source.id
}