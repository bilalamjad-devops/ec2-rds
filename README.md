# How to Connect Python Flask to AWS RDS MySQL Using .env Configuration Files
`aap.py`

```python
import os
from flask import Flask, render_template, request
import mysql.connector
import requests
from dotenv import load_dotenv

# Load variables from local .env file profile
load_dotenv()

app = Flask(__name__)

# Load database configuration from environment variables
RDS_HOST = os.getenv("DB_HOST", "127.0.0.1")
RDS_USER = os.getenv("DB_USER", "root")
RDS_PASSWORD = os.getenv("DB_PASSWORD", "password123")
RDS_DATABASE = os.getenv("DB_NAME", "web_db")

def get_db_connection():
    # Create a connection to MySQL
    conn = mysql.connector.connect(
        host=RDS_HOST,
        user=RDS_USER,
        password=RDS_PASSWORD
    )
    cursor = conn.cursor()
    
    # Create database and table if they do not already exist
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
    """Fetches real-time AWS EC2 infrastructure context using IMDSv2"""
    try:
        # Step A: Request a secure IMDSv2 Access Token Session
        token_url = "http://169.254.169.254/latest/api/token"
        token_headers = {"X-aws-ec2-metadata-token-ttl-seconds": "21600"}
        token = requests.put(token_url, headers=token_headers, timeout=2).text

        headers = {"X-aws-ec2-metadata-token": token}

        # Step B: Query instance identity parameters using the active token session
        id_url = "http://169.254.169.254/latest/meta-data/instance-id"
        instance_id = requests.get(id_url, headers=headers, timeout=2).text

        az_url = "http://169.254.169.254/latest/meta-data/placement/availability-zone"
        az = requests.get(az_url, headers=headers, timeout=2).text

        return instance_id, az
    except Exception:
        # Fallback context if running outside an active AWS environment locally
        return "Local-Machine-Host", "Local-Testing-Zone"

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
    
    try:
        conn, cursor = get_db_connection()
        cursor.execute("INSERT INTO users (content) VALUES (%s)", (data,))
        conn.commit()
        cursor.close()
        conn.close()
        message = f"🎉 Success! Saved '{data}' directly to AWS RDS MySQL."
    except Exception as e:
        message = f"❌ Database Writing Error: {e}"

    instance_id, az = get_instance_metadata()
    return render_template(
        "index.html",
        message=message,
        instance_id=instance_id,
        availability_zone=az
    )

if __name__ == "__main__":
    # Serves the web interface on port 5000 externally
    app.run(host="0.0.0.0", port=5000, debug=True)
```

`.env`

```variables
DB_HOST=your-rds-database-endpoint.xxxxxx.us-east-1.rds.amazonaws.com
DB_USER=admin
DB_PASSWORD=SecurePassword123
DB_NAME=web_db
```


`requirements.txt`

```python
Flask
mysql-connector-python
requests
python-dotenv
```

`templates/index.html`

```html
<!DOCTYPE html>
<html>
<head>
    <title>EC2 + RDS Demo</title>
</head>
<body>
<!--
    <h1>2-Tier AWS Application</h1>

    <h3>EC2 Metadata</h3>
-->
    <p>
        <strong>Instance ID:</strong>
        {{ instance_id }}
    </p>

    <p>
        <strong>Availability Zone:</strong>
        {{ availability_zone }}
    </p>

    <hr>

    <form action="/submit" method="POST">

        <input
            type="text"
            name="user_data"
            placeholder="Enter text"
            required
        >

        <button type="submit">
            Submit
        </button>

    </form>

    {% if message %}
        <h3>{{ message }}</h3>
    {% endif %}

</body>
</html>
```







```bash
pip install -r requirements.txt
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
