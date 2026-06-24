# How to Connect Python Flask to AWS RDS MySQL Using .env Configuration Files

We are using Terraform to create:
- EC2 Instance
- RDS Database
- 2 Security groups:
    - one for Web Server
    - other for Database
Bilal bhai, yeh code **bohot hi zabardast aur structured** hai! Aap ne is mein IMDSv2 ka use kiya hai jo bilkul up-to-date AWS security practices ke mutabik hai, aur Security Groups ki chaining (`security_groups = [aws_security_group.web_sg.id]`) bilkul perfect production standard par hai.

Lekin agar hum is code ko isi tarah execute karenge, toh is mein **2 bohot bade gaps (bugs)** hain jis ki wajah se aap ka final test fail ho jayega. Chalein, pehle unhein samajhte hain aur fix karte hain:

---

### ⚠️ Gaps & Issues in Current Code

#### 1. EC2 par Automated Installation (User Data) Missing Hai

Aap ne description mein toh likha hai *"Install Flask automatically using User Data"*, lekin aap ke Terraform `aws_instance` block ke andar `user_data` ka parameter bilkul khali hai. Agar user data nahi hoga, toh EC2 automatic python, flask, aur repositories setup nahi karega.

#### 2. Dynamic `.env` File Creation Structure Missing Hai

Aap ke Python code ko chalne ke liye `.env` file chahiye jo RDS ka endpoint read kare. Jab tak RDS create nahi hota, humein endpoint pata nahi hota. Yeh kaam humein Terraform ke user data ke zariye dynamic script se auto-generate karwana hoga.

---

### 🛠️ The Fixed & Complete Terraform Code

Yahan aap ka updated `main.tf` hai jahan main ne pure **Automated User Data Bash Script** ko inject kar diya hai. Yeh script automatic system ko update karegi, clone karegi, dynamic `.env` file bana kar RDS ka endpoint auto-inject karegi, aur background mein app run kar degi:

```tf
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
  region = "us-east-1" 
}

# ==============================================================================
# 2. SECURITY GROUPS (WEB & DATABASE TIER)
# ==============================================================================
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

resource "aws_security_group" "db_sg" {
  name        = "mysql-rds-security-group"
  description = "Isolates database traffic exclusively to the EC2 web tier"

  ingress {
    description     = "Inbound MySQL traffic constraint"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==============================================================================
# 3. AWS RDS MYSQL DATABASE TIER
# ==============================================================================
resource "aws_db_instance" "mysql_rds" {
  allocated_storage      = 20
  db_name                = "web_db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro" 
  username               = "admin"
  password               = "SecurePassword123" 
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
}

# ==============================================================================
# 4. COMPUTE TIER WITH DYNAMIC USER DATA BOOTSTRAPPING
# ==============================================================================
resource "aws_instance" "web_app_server" {
  ami                    = "ami-0c7217cdde317cfec" # Clean Ubuntu 22.04 LTS (us-east-1)
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # 🔥 FIXED: Automated bootstrap user_data injected dynamically
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install python3-pip python3-dev git -y

              # Repo setup
              cd /home/ubuntu
              git clone https://github.com/bilalamjad-devops/ec2-rds.git
              cd ec2-rds

              # Requirements mapping
              pip3 install -r requirements.txt

              # 🔥 Dynamic generation of .env file mapping to active RDS Endpoint
              echo "DB_HOST=${aws_db_instance.mysql_rds.address}" > .env
              echo "DB_USER=${aws_db_instance.mysql_rds.username}" >> .env
              echo "DB_PASSWORD=SecurePassword123" >> .env
              echo "DB_NAME=web_db" >> .env

              # Background Execution
              nohup python3 app.py > flask.log 2>&1 &
              EOF

  tags = {
    Name = "2-Tier-Flask-Environment-Server"
  }
}

# ==============================================================================
# 5. OUTPUTS (To fetch tracking URL easily)
# ==============================================================================
output "ec2_public_url" {
  value       = "http://${aws_instance.web_app_server.public_ip}:5000"
  description = "The public URL to test your application"
}

```

---

### 🎯 Next Plan Setup

Aap ka yeh logic base bilkul ready hai. Jab aap is simple 2-Tier framework ka `terraform apply` verify kar lenge, toh agla step Hamzah Bhai ke project demand ke mutabik direct yeh hoga:

1. Hum automatic network isolation ke liye **Custom VPC** layout map karenge.
2. `aws_instance` resource block ko convert kar ke production-grade **Launch Template** aur **Auto Scaling Group (ASG)** mein convert karenge.
3. Traffic distribution ke liye samne ek **Application Load Balancer (ALB)** block set kar denge.

Yeh strategy bilkul aag laga degi! Aap is architecture code ko deploy kar ke output check karein, phir mujhe batayein hum is code ko expand karte hain.
