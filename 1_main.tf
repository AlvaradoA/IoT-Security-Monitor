provider "aws" {
  region = var.aws_region
}

# SECURITY GROUPS
resource "aws_security_group" "collector_sg" {
  name        = "iot-collector-sg"
  description = "Allow SSH, MQTT"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 1883
    to_port     = 1883
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # For Raspberry Pi
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "IoT-Collector-SG" }
}

resource "aws_security_group" "elk_sg" {
  name        = "iot-elk-sg"
  description = "Allow SSH, Kibana, and Elasticsearch from Collector"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 5601
    to_port     = 5601
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # For Kibana UI
  }
  # Allow traffic from the Collector to Elasticsearch
  ingress {
    from_port       = 9200
    to_port         = 9200
    protocol        = "tcp"
    security_groups = [aws_security_group.collector_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "IoT-ELK-SG" }
}

# ELASTIC IP ADDRESSES
resource "aws_eip" "collector_eip" {
  domain = "vpc"
  tags   = { Name = "IoT-Collector-EIP" }
}

resource "aws_eip" "elk_eip" {
  domain = "vpc"
  tags   = { Name = "IoT-ELK-EIP" }
}

# S3 BUCKET & FLOW LOGS
resource "aws_s3_bucket" "flow_log_bucket" {
  bucket_prefix = var.s3_bucket_prefix 
  tags          = { Name = "VPC Flow Log Bucket" }
  force_destroy = true
}

resource "aws_flow_log" "iot_vpc_flow_log" {
  # iam_role_arn         = var.lab_role_arn
  log_destination_type = "s3"
  log_destination      = aws_s3_bucket.flow_log_bucket.arn
  traffic_type         = "ALL"
  vpc_id               = data.aws_vpc.default.id
  tags                 = { Name = "IoT VPC Flow Log" }
}


# This policy allows the VPC Flow Log service to write to our new S3 bucket
resource "aws_s3_bucket_policy" "flow_log_bucket_policy" {
  bucket = aws_s3_bucket.flow_log_bucket.id
  policy = data.aws_iam_policy_document.flow_log_bucket_policy_doc.json
}

# ATHENA SETUP (The "Cloud-Native" Log Viewer)

# 1. Create a Workgroup for query results
resource "aws_s3_bucket" "athena_results" {
  bucket_prefix = "athena-results-"
  force_destroy = true
}

resource "aws_athena_workgroup" "iot_analysis" {
  name = "iot_analysis_workgroup"
  force_destroy = true

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/output/"
    }
  }
}

# 2. Create the Database
resource "aws_athena_database" "flow_logs_db" {
  name   = "vpc_flow_logs_db"
  bucket = aws_s3_bucket.athena_results.bucket
}

# 3. Create the Table Schema for VPC Flow Logs
resource "aws_glue_catalog_table" "vpc_flow_logs" {
  name          = "vpc_flow_logs"
  database_name = aws_athena_database.flow_logs_db.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "EXTERNAL"            = "TRUE"
    "skip.header.line.count" = "1"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.flow_log_bucket.bucket}/AWSLogs/${data.aws_caller_identity.current.account_id}/vpcflowlogs/${var.aws_region}/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "vpc-flow-logs-serde"
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
      parameters = {
        "field.delim" = " "
        "serialization.format" = " "
      }
    }

    # This schema matches the default VPC Flow Log format
    columns {
      name = "version"
      type = "int"
    }
    columns {
      name = "account_id"
      type = "string"
    }
    columns {
      name = "interface_id"
      type = "string"
    }
    columns {
      name = "srcaddr"
      type = "string"
    }
    columns {
      name = "dstaddr"
      type = "string"
    }
    columns {
      name = "srcport"
      type = "int"
    }
    columns {
      name = "dstport"
      type = "int"
    }
    columns {
      name = "protocol"
      type = "int"
    }
    columns {
      name = "packets"
      type = "bigint"
    }
    columns {
      name = "bytes"
      type = "bigint"
    }
    columns {
      name = "start"
      type = "bigint"
    }
    columns {
      name = "end"
      type = "bigint"
    }
    columns {
      name = "action"
      type = "string"
    }
    columns {
      name = "log_status"
      type = "string"
    }
  }
}

# AWS IOT CORE SETUP-

# 1. Create the IoT Thing
resource "aws_iot_thing" "raspberry_pi" {
  name = "RaspberryPi-IoT-Device"
}

# 2. Create the IoT Policy
resource "aws_iot_policy" "pi_policy" {
  name = "RaspberryPi-Policy"
  policy = data.aws_iam_policy_document.pi_policy_doc.json
}

# 3. Create the Certificate and Keys
resource "aws_iot_certificate" "pi_cert" {
  active = true
}

# 4. Attach Policy to Certificate
resource "aws_iot_policy_attachment" "pi_cert_policy_attach" {
  policy = aws_iot_policy.pi_policy.name
  target = aws_iot_certificate.pi_cert.arn
}

# 5. Attach Thing to Certificate
resource "aws_iot_thing_principal_attachment" "pi_cert_thing_attach" {
  principal = aws_iot_certificate.pi_cert.arn
  thing     = aws_iot_thing.raspberry_pi.name
}

# 6. Save Certificates to Local Files (for your Pi)
resource "local_file" "cert_pem" {
  content  = aws_iot_certificate.pi_cert.certificate_pem
  filename = "certs/certificate.pem.crt"
}

resource "local_file" "private_key" {
  content  = aws_iot_certificate.pi_cert.private_key
  filename = "certs/private.pem.key"
}

resource "local_file" "public_key" {
  content  = aws_iot_certificate.pi_cert.public_key
  filename = "certs/public.pem.key"
}

resource "local_file" "root_ca" {
  content  = data.http.root_ca.response_body
  filename = "certs/AmazonRootCA1.pem"
}


# VM 1: ELK Stack (Kibana, Elasticsearch)
resource "aws_instance" "elk" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.medium"
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.elk_sg.id]
  user_data              = file("4_init.sh")
  iam_instance_profile   = var.lab_instance_profile_name

  tags = { Name = "IoT-ELK-Server" }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("${var.key_name}.pem")
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "while [ ! -d /opt/iot_stack ]; do echo 'Waiting for init.sh...'; sleep 5; done",
      "while ! systemctl is-active docker; do echo 'Waiting for Docker...'; sleep 5; done"
    ]
  }

  provisioner "file" {
    source      = "6_docker-compose-elk.yml"
    destination = "/opt/iot_stack/docker-compose.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'ELASTIC_PASSWORD=${var.elastic_password}' | sudo tee /opt/iot_stack/.env > /dev/null",
      "cd /opt/iot_stack",
      "sudo docker-compose up -d"
    ]
  }
}

# VM 2: Collector (Suricata, Filebeat, Mosquitto)
resource "aws_instance" "collector" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.medium"
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.collector_sg.id]
  user_data              = file("4_init.sh")
  iam_instance_profile   = var.lab_instance_profile_name

  tags = { Name = "IoT-Collector-Server" }

  # This instance depends on the ELK instance being created first
  # so it can get its private IP address.
  depends_on = [aws_instance.elk]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("${var.key_name}.pem")
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "while [ ! -d /opt/iot_stack ]; do echo 'Waiting for init.sh...'; sleep 5; done",
      "while ! systemctl is-active docker; do echo 'Waiting for Docker...'; sleep 5; done"
    ]
  }

  provisioner "file" {
    source      = "5_docker-compose-collector.yml"
    destination = "/opt/iot_stack/docker-compose.yml"
  }

  provisioner "file" {
    source      = "config/"
    destination = "/opt/iot_stack/config"
  }

  # Connects the two servers
  provisioner "remote-exec" {
    inline = [
      # 1. Create the .env file 
      "echo 'ELASTIC_PASSWORD=${var.elastic_password}' | sudo tee /opt/iot_stack/.env > /dev/null",

      # 2. Replace the Elasticsearch placeholder
      "sudo sed -i 's/ELK_SERVER_IP_PLACEHOLDER:9200/${aws_instance.elk.private_ip}:9200/g' /opt/iot_stack/config/filebeat.yml",

      # 3. Replace the Kibana placeholder
      "sudo sed -i 's/ELK_SERVER_IP_PLACEHOLDER:5601/${aws_instance.elk.private_ip}:5601/g' /opt/iot_stack/config/filebeat.yml",

      # 4. Change filebeat.yml owner to 'root'
      "sudo chown root:root /opt/iot_stack/config/filebeat.yml",

      # 5. Start all services (including the 'filebeat-setup' init container)
      "cd /opt/iot_stack",
      "sudo docker-compose up -d"
    ]
  }
}

# EIP ASSOCIATIONS
resource "aws_eip_association" "collector_eip_assoc" {
  instance_id   = aws_instance.collector.id
  allocation_id = aws_eip.collector_eip.id
}

resource "aws_eip_association" "elk_eip_assoc" {
  instance_id   = aws_instance.elk.id
  allocation_id = aws_eip.elk_eip.id
}

