from flask import Flask, render_template, request
import mysql.connector
import requests

app = Flask(__name__)

# RDS Endpoint
RDS_HOST = "YOUR-RDS-ENDPOINT"
RDS_USER = "admin"
RDS_PASSWORD = "password123"
RDS_DATABASE = "web_db"


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
            "http://169.254.169.254/latest/api/token",
            headers={
                "X-aws-ec2-metadata-token-ttl-seconds": "21600"
            },
            timeout=2
        ).text

        headers = {
            "X-aws-ec2-metadata-token": token
        }

        instance_id = requests.get(
            "http://169.254.169.254/latest/meta-data/instance-id",
            headers=headers,
            timeout=2
        ).text

        az = requests.get(
            "http://169.254.169.254/latest/meta-data/placement/availability-zone",
            headers=headers,
            timeout=2
        ).text

        return instance_id, az

    except:
        return "Unknown", "Unknown"


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

    cursor.execute(
        "INSERT INTO users (content) VALUES (%s)",
        (data,)
    )

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
