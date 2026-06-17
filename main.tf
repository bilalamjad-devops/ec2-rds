# ==============================================================================
# 1. PROVIDER & BACKEND DEFINITIONS
# ==============================================================================
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # Changes this to your targeted lab region
}

# ==============================================================================
# 2. ISOLATED NETWORK FIREWALLS (SECURITY GROUPS)
# ==============================================================================

# Web Application Security Group
resource "aws_security_group" "web_sg" {
  name        = "flask-ec2-security-group"
  description = "Allows SSH and Application Port 5000"

  ingress {
    description = "SSH access channel"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Flask custom port listener"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Database Tier Isolated Security Group
resource "aws_security_group" "db_sg" {
  name        = "mysql-rds-security-group"
  description = "Isolates database traffic exclusively to the EC2 web tier"

  ingress {
    description     = "Inbound MySQL traffic constraint"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id] # Strict architectural bridge
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==============================================================================
# 3. AWS MANAGED DATA STORE TIER (RDS MYSQL)
# ==============================================================================
resource "aws_db_instance" "mysql_rds" {
  allocated_storage      = 20
  db_name                = "web_db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro" # Matches your resource plan requirement
  username               = "admin"
  password               = "SecurePassword123" # Match with your app's intended profile
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
}

# ==============================================================================
# 4. COMPUTE TIER WITH AUTOMATED DYNAMIC .ENV BOOTSTRAPPING
# ==============================================================================
resource "aws_instance" "web_app_server" {
  ami           = "ami-0c7217cdde317cfec" # Clean Ubuntu 22.04 LTS image (us-east-1)
  instance_type = "t2.micro"             # Free-tier compute unit
  
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Optional: Uncomment and provide your key name if you intend to execute manual test connections
  # key_name               = "your-aws-ssh-key"

  # User Data script that automatically constructs the app profile
  user_data = <<-EOF
              #!/bin/bash
              # 1. System update and tool deployment
              sudo apt-get update -y
              sudo apt-get install -y git python3 python3-pip

              # 2. Workspace initialization
              mkdir -p /home/ubuntu/app
              cd /home/ubuntu/app

              # 3. Clones code repository contents (Replace with your actual public repository link)
              git clone https://github.com/YOUR_USERNAME/YOUR_FLASK_REPO.git .

              # 4. DYNAMIC ENVIRONMENT CREATION
              # Automatically writes a custom .env file injecting the live generated RDS Endpoint
              echo "DB_HOST=${aws_db_instance.mysql_rds.address}" > .env
              echo "DB_USER=admin" >> .env
              echo "DB_PASSWORD=SecurePassword123" >> .env
              echo "DB_NAME=web_db" >> .env

              # Ensure user permissions align cleanly
              chown ubuntu:ubuntu .env

              # 5. Dependency installation using your standard requirements format
              pip3 install -r requirements.txt --break-system-packages

              # 6. Fire up background application listener
              nohup python3 app.py > flask.log 2>&1 &
              EOF

  tags = {
    Name = "2-Tier-Flask-Environment-Server"
  }
}

# ==============================================================================
# 5. AUTOMATED LIVE LAB ACCESS OUTPUTS
# ==============================================================================
output "deployment_access_url" {
  description = "Copy and access this address route within your local browser profile"
  value       = "http://${aws_instance.web_app_server.public_ip}:5000"
}

output "rds_internal_endpoint" {
  description = "The database network address generated dynamically by AWS"
  value       = aws_db_instance.mysql_rds.address
}
