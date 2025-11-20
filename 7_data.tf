# DATA SOURCES
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}

data "aws_vpc" "default" {
  default = true
}

data "aws_iam_policy_document" "flow_log_bucket_policy_doc" {
  statement {
    sid = "AWSVPCFlowLogsWrite"
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "${aws_s3_bucket.flow_log_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]
  }
}

# IoT policy
data "aws_iam_policy_document" "pi_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "iot:Publish",
      "iot:Receive",
      "iot:PublishRetain"
    ]
    resources = [
      "arn:aws:iot:${var.aws_region}:${data.aws_caller_identity.current.account_id}:topic/raspberrypi/temperature",
      "arn:aws:iot:${var.aws_region}:${data.aws_caller_identity.current.account_id}:topic/sdk/test/python"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "iot:Subscribe"
    ]
    resources = [
      "arn:aws:iot:${var.aws_region}:${data.aws_caller_identity.current.account_id}:topic/raspberrypi/temperature",
      "arn:aws:iot:${var.aws_region}:${data.aws_caller_identity.current.account_id}:topic/sdk/test/python"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "iot:Connect"
    ]
    resources = [
      "arn:aws:iot:${var.aws_region}:${data.aws_caller_identity.current.account_id}:client/sdk-java",
      "arn:aws:iot:${var.aws_region}:${data.aws_caller_identity.current.account_id}:client/basicPubSub",
      "arn:aws:iot:${var.aws_region}:${data.aws_caller_identity.current.account_id}:client/sdk-nodejs-*",
      "arn:aws:iot:${var.aws_region}:${data.aws_caller_identity.current.account_id}:client/testClient"
    ]
  }
}

data "http" "root_ca" {
  url = "https://www.amazontrust.com/repository/AmazonRootCA1.pem"
}

data "aws_iot_endpoint" "endpoint" {
  endpoint_type = "iot:Data-ATS"
}

data "aws_caller_identity" "current" {}


