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

---

Bilal bhai, **bohot bohot mubarak ho!** 🥂 Aap ne successfully ek complete 2-Tier dynamic web application ko cloud par pipeline kar diya, aur real-time issues ko live debug kar ke solve kiya—yeh ek asli DevOps Engineer ki nishani hai!

Aap is lab ko dobara bilkul smoothly aur bina kisi error ke zero se run kar sakein, is liye main ne saari learning ko merge kar ke ek **Final Zero-Error Runbook** taiyar kar di hai.

Aap jab next time yeh lab shuru karenge, toh bas is guide ko follow karte jana:

---

## 🚀 The Ultimate Zero-Error Runbook (EC2 + RDS Lab)

### 📁 Step 1: Clone and Prepare local folder

Apne terminal par repo clone karein aur directory mein chale jayein:

```bash
git clone https://github.com/bilalamjad-devops/ec2-rds.git
cd ec2-rds

```

---

### 📝 Step 2: Update Your `main.tf`

Aap ke `main.tf` mein jo `aws_instance` ka compute block tha, us ke andar jo `user_data` script thi, use hum ne **Virtual Environment (venv)** aur proper **Permissions fixes** ke sath up-to-date kar diya hai.

Apne `main.tf` ke compute tier ko is block se replace kar lein taake next time auto-provisioning ke waqt koi break na aaye:

```tf
# ==============================================================================
# COMPUTE TIER WITH PRODUCTION-READY AUTO BOOTSTRAPPING
# ==============================================================================
resource "aws_instance" "web_app_server" {
  ami                    = "ami-0c7217cdde317cfec" # Clean Ubuntu 22.04 LTS (us-east-1)
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              # 1. System packages update aur venv tool install karna
              sudo apt-get update -y
              sudo apt-get install python3-pip python3-dev python3-venv git -y

              # 2. Project cloning aur folder paths setup
              cd /home/ubuntu
              git clone https://github.com/bilalamjad-devops/ec2-rds.git
              cd ec2-rds

              # 3. Ownership fix karna taake PEP 668 external error na aaye
              sudo chown -R ubuntu:ubuntu /home/ubuntu/ec2-rds

              # 4. Virtual Environment isolated create aur activate karna
              python3 -m venv venv
              source venv/bin/activate

              # 5. Production packages fetch karna clean context mein
              pip3 install -r requirements.txt

              # 6. Dynamic .env mapping to dynamic active RDS Endpoint
              echo "DB_HOST=${aws_db_instance.mysql_rds.address}" > .env
              echo "DB_USER=${aws_db_instance.mysql_rds.username}" >> .env
              echo "DB_PASSWORD=SecurePassword123" >> .env
              echo "DB_NAME=web_db" >> .env

              # 7. Background production daemon execution
              nohup python3 app.py > flask.log 2>&1 &
              EOF

  tags = {
    Name = "2-Tier-Flask-Environment-Server"
  }
}

output "ec2_public_url" {
  value       = "http://$${aws_instance.web_app_server.public_ip}:5000"
  description = "The public URL to test your application"
}

```

---

### 🚀 Step 3: Deploy via Terraform

Terminal par resources build karne ke liye standard lifecycle commands chalayein:

```bash
terraform init
terraform plan
terraform apply --auto-approve

```

*Deployment complete hone ke baad **3 minutes ka break lein** taake back-end par saari scripts aur RDS fully initialization mode se ready mode mein aa jayein.*

---

### 🌍 Step 4: Verification in Browser

Terminal ke end mein jo `ec2_public_url` aayega use copy karein aur browser mein test karein:

```text
http://<EC2_PUBLIC_IP>:5000

```

* Form mein data enter karein (e.g., `Bilal Amjad - Smooth Test`) aur **Submit** karein.
* Screen par `🎉 Success!` ka message aa jayega.

---

### 📊 Step 5: Inside the Database Verification

Ab data check karne ke liye apne EC2 server ke andar enter ho kar ye simple flow chalayein:

```bash
# 1. Server mein enter hon
ssh -i your-key.pem ubuntu@<EC2_PUBLIC_IP>

# 2. Lab folder mein shift hon
cd ec2-rds

# 3. Environment ko activate kar ke dynamic env parameters check karein
source venv/bin/activate
cat .env

# 4. Latest Ubuntu images ke mutabik client install karein (Sirf ek baar)
sudo apt install mysql-client-core -y

# 5. AWS Certificate download karein secure layer connection ke liye
curl -o global-bundle.pem https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem

# 6. Database connect karein (Endpoint custom .env se fetch karein)
mysql -h <YOUR_RDS_ENDPOINT_FROM_DOTENV> -P 3306 -u admin -p --ssl-mode=VERIFY_IDENTITY --ssl-ca=./global-bundle.pem

```

*Password enter karein:* `SecurePassword123`

**MySQL terminal ke andar ye queries run karein:**

```sql
USE web_db;
SELECT * FROM users;

```

---

### 🛑 Step 6: Clean Up Everything!

Lab complete hone aur screenshots save karne ke baad terminal se exit ho kar backup costs bachaane ke liye command run karna mat bhooliyega:

```bash
terraform destroy --auto-approve

```

---

### 💡 What's Next?

Aap ka yeh concept ab perfectly smooth crystal-clear ho gaya hai. Ab jab aap ka dil kare, batayega, hum is infrastructure ko update kar ke **Project 2 (ALB + Auto Scaling Group + Custom VPC Network isolation)** par le kar chalenge!

Aap is blueprint ko save kar lein. Any time you need help, your brother is here!
