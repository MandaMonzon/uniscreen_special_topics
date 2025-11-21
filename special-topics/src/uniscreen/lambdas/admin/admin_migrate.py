import os
import json
import ssl
import boto3
import pg8000
from typing import List, Tuple


def response(status_code: int, body: dict):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
        "isBase64Encoded": False,
    }


def get_db_credentials(secret_arn: str, region: str) -> Tuple[str, str]:
    sm = boto3.client("secretsmanager", region_name=region)
    sec = sm.get_secret_value(SecretId=secret_arn)
    data = sec.get("SecretString") or "{}"
    obj = json.loads(data)
    # Secrets Manager format for RDS master secret usually contains 'username' and 'password'
    return obj.get("username"), obj.get("password")


def connect_db(user: str, password: str, host: str, port: int, database: str):
    # Use TLS by default
    ctx = ssl.create_default_context()
    return pg8000.connect(user=user, password=password, host=host, port=port, database=database, ssl_context=ctx)


def discover_migrations() -> List[str]:
    """
    Read SQL files from local 'migrations' folder packaged with the Lambda.
    The folder path is relative to this file. Returns sorted list of absolute paths.
    """
    base_dir = os.path.dirname(os.path.abspath(__file__))
    mig_dir = os.path.join(base_dir, "migrations")
    if not os.path.isdir(mig_dir):
        return []
    files = [os.path.join(mig_dir, f) for f in os.listdir(mig_dir) if f.lower().endswith(".sql")]
    files.sort()  # lexicographic order -> 001, 002, 003...
    return files


def run_sql_file(cur, path: str):
    with open(path, "r", encoding="utf-8") as f:
        sql = f.read()

    # Build statements while ignoring SQL comments.
    statements: List[str] = []
    buff: List[str] = []
    in_block_comment = False

    for raw_line in sql.splitlines():
        line = raw_line.strip()

        # Handle block comments /* ... */
        if in_block_comment:
            if "*/" in line:
                in_block_comment = False
            continue
        if line.startswith("/*"):
            if "*/" not in line:
                in_block_comment = True
            continue

        # Skip single-line comments and empty lines
        if line.startswith("--") or line == "":
            continue

        # Keep original line (preserve formatting) for execution
        buff.append(raw_line)

        # Statement terminator
        if line.endswith(";"):
            st = "\n".join(buff).strip()
            if st:
                statements.append(st)
            buff = []

    # Append any trailing statement without semicolon
    if buff:
        st = "\n".join(buff).strip()
        if st:
            statements.append(st)

    for st in statements:
        cur.execute(st)


def lambda_handler(event, context):
    try:
        region = os.environ.get("REGION")
        db_endpoint = os.environ.get("DB_ENDPOINT")
        db_name = os.environ.get("DB_NAME")
        db_port = int(os.environ.get("DB_PORT", "5432"))
        rds_secret_arn = os.environ.get("RDS_SECRET_ID")

        if not all([region, db_endpoint, db_name, rds_secret_arn]):
            return response(500, {"error": "Missing required environment variables (REGION/DB_ENDPOINT/DB_NAME/RDS_SECRET_ID)"})

        user, password = get_db_credentials(rds_secret_arn, region)
        if not user or not password:
            return response(500, {"error": "Unable to resolve DB credentials from Secrets Manager"})

        migrations = discover_migrations()
        if not migrations:
            return response(200, {"message": "No migrations found (migrations/ folder empty or missing)", "applied": []})

        applied = []
        with connect_db(user, password, db_endpoint, db_port, db_name) as conn:
            conn.autocommit = True
            with conn.cursor() as cur:
                for path in migrations:
                    run_sql_file(cur, path)
                    applied.append(os.path.basename(path))

        return response(200, {"message": "Migrations applied successfully", "applied": applied})
    except Exception as e:
        return response(500, {"error": str(e)})
