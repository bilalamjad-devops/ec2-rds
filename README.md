```bash
pip install Flask mysql-connector-python requests
```
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
