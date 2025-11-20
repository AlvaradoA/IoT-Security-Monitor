output "collector_public_ip" {
  description = "The public IP of the Collector. Use this for your Raspberry Pi script."
  value       = aws_eip.collector_eip.public_ip
}

output "kibana_url" {
  description = "The URL to access the Kibana dashboard."
  value       = "http://${aws_eip.elk_eip.public_ip}:5601"
}

output "ssh_command_collector" {
  description = "The command to SSH into the COLLECTOR instance."
  value       = "ssh -i ${var.key_name}.pem ubuntu@${aws_eip.collector_eip.public_ip}"
}

output "ssh_command_elk" {
  description = "The command to SSH into the ELK STACK instance."
  value       = "ssh -i ${var.key_name}.pem ubuntu@${aws_eip.elk_eip.public_ip}"
}

output "flow_log_s3_bucket_name" {
  description = "The name of the S3 bucket where VPC flow logs are being stored."
  value       = aws_s3_bucket.flow_log_bucket.bucket
}

output "aws_iot_endpoint" {
  description = "Your AWS IoT Core Endpoint URL. Use this for your Pi's .env file."
  value       = data.aws_iot_endpoint.endpoint.endpoint_address
}