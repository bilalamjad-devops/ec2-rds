# How to Connect Python Flask to AWS RDS MySQL Using .env Configuration Files
`aap.py`

```python
import os
from flask import Flask, render_template, request
import mysql.connector
import requests
# 1. Import the library to read .env file
from dotenv import load_dotenv

# 2. Load the variables from .env file automatically
load_dotenv()

app = Flask(__name__)

# Fetch database credentials from memory
RDS_HOST = os.getenv("DB_HOST", "127.0.0.1")
RDS_USER = os.getenv("DB_USER", "root")
RDS_PASSWORD = os.getenv("DB_PASSWORD", "password123")
RDS_DATABASE = os.getenv("DB_NAME", "web_db")


def get_db_connection():
    conn = mysql.connector.connect(
        host=RDS_HOST,
        user=RDS_USER,
        password=RDS_PASSWORD
    )
    cursor = conn.cursor()
    cursor.execute(f"CREATE DATABASE IF NOT EXISTS {RDS_DATABASE}")
    cursor.execute(f"USE {RDS_DATABASE}")
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INT AUTO_INCREMENT PRIMARY KEY,
            content VARCHAR(255)
        )
    """)
    conn.commit()
    return conn, cursor


def get_instance_metadata():
    try:
        token = requests.put(
            "http://169.254.169",
            headers={"X-aws-ec2-metadata-token-ttl-seconds": "21600"},
            timeout=2
        ).text

        headers = {"X-aws-ec2-metadata-token": token}

        instance_id = requests.get(
            "http://169.254.169",
            headers=headers,
            timeout=2
        ).text

        az = requests.get(
            "http://169.254.169",
            headers=headers,
            timeout=2
        ).text

        return instance_id, az
    except:
        return "Local-Machine", "Local-Zone"


@app.route("/")
def index():
    instance_id, az = get_instance_metadata()
    return render_template(
        "index.html",
        instance_id=instance_id,
        availability_zone=az
    )


@app.route("/submit", methods=["POST"])
def submit():
    data = request.form["user_data"]
    conn, cursor = get_db_connection()
    cursor.execute("INSERT INTO users (content) VALUES (%s)", (data,))
    conn.commit()
    cursor.close()
    conn.close()

    instance_id, az = get_instance_metadata()
    return render_template(
        "index.html",
        message=f"Saved: {data}",
        instance_id=instance_id,
        availability_zone=az
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

```

`.env`

```variables
DB_HOST=://amazonaws.com
DB_USER=admin
DB_PASSWORD=password123
DB_NAME=web_db
```







```bash
pip install Flask mysql-connector-python requests
```

python3 app.py
## Terraform (Simple Version)

Create:

### Security Group for EC2

Allow:

```text
22
5000
```

### Security Group for RDS

Allow:

```text
3306
Source = EC2 Security Group
```

### EC2

Install Flask automatically using User Data.

### RDS

Create:

```text
MySQL
db.t3.micro
20 GB
```

---

## User Data

Put this inside EC2:

```bash
#!/bin/bash

yum update -y

yum install git python3 -y

pip3 install Flask mysql-connector-python requests
```

---

## Success Test

Open:

```text
http://EC2-PUBLIC-IP:5000
```

You should see:

```text
Instance ID:
i-0abc123

Availability Zone:
us-east-1a
```

Submit:

```text
Bilal Amjad
```

Connect to RDS:

```bash
mysql -h <rds-endpoint> -u admin -p
```

```sql
USE web_db;

SELECT * FROM users;
```

Output:

```text
+----+--------------+
| id | content      |
+----+--------------+
|  1 | Bilal Amjad  |
+----+--------------+
```

Once you get this working, the next step is extremely easy:

```text
EC2
     ↓
Launch Template
     ↓
ASG
     ↓
ALB
     ↓
RDS
```

The Flask code will remain almost unchanged. Only the infrastructure will grow. This is the same path many AWS engineers follow when building a production-style 2-tier architecture.
