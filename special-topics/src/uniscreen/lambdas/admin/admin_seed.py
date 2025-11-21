import os
import json
import ssl
import boto3
import pg8000
from typing import Tuple


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
    return obj.get("username"), obj.get("password")


def connect_db(user: str, password: str, host: str, port: int, database: str):
    ctx = ssl.create_default_context()
    return pg8000.connect(user=user, password=password, host=host, port=port, database=database, ssl_context=ctx)


def table_count(cur, table: str) -> int:
    cur.execute(f"SELECT COUNT(*) FROM {table}")
    (count,) = cur.fetchone()
    return int(count)


def ensure_user(cur, email: str) -> int:
    # Admin seed: create a simple user row if not exists; password_hash left empty
    cur.execute("SELECT id FROM public.users WHERE email=%s", (email,))
    row = cur.fetchone()
    if row:
        return int(row[0])
    cur.execute("INSERT INTO public.users (email, password_hash) VALUES (%s, %s) RETURNING id", (email, ""))
    (new_id,) = cur.fetchone()
    return int(new_id)


def insert_movie(cur, title: str, year: int, director: str, actors: str, plot: str, poster_url: str) -> int:
    cur.execute(
        """
        INSERT INTO public.movies (title, year, director, actors, plot, poster_url)
        VALUES (%s, %s, %s, %s, %s, %s)
        RETURNING id
        """,
        (title, year, director, actors, plot, poster_url),
    )
    (movie_id,) = cur.fetchone()
    return int(movie_id)


def insert_favorite(cur, user_id: int, movie_id: int):
    # Respect unique (user_id, movie_id)
    try:
        cur.execute(
            "INSERT INTO public.favorites (user_id, movie_id) VALUES (%s, %s) ON CONFLICT DO NOTHING",
            (user_id, movie_id),
        )
    except Exception:
        # Ignore conflicts if constraint exists
        pass


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

        seeded = {"movies_added": 0, "favorites_added": 0}
        with connect_db(user, password, db_endpoint, db_port, db_name) as conn:
            conn.autocommit = True
            with conn.cursor() as cur:
                # Only seed if empty
                movies_count = table_count(cur, "public.movies")
                users_count = table_count(cur, "public.users")
                favorites_count = table_count(cur, "public.favorites")

                if users_count == 0:
                    # create a default user
                    u1 = ensure_user(cur, "admin@uniscreen.local")
                else:
                    # get any user
                    cur.execute("SELECT id FROM public.users ORDER BY id LIMIT 1")
                    (u1,) = cur.fetchone()

                # Seed movies only if table empty
                if movies_count == 0:
                    m1 = insert_movie(
                        cur,
                        "Inception",
                        2010,
                        "Christopher Nolan",
                        "Leonardo DiCaprio, Joseph Gordon-Levitt, Elliot Page",
                        "A thief who steals corporate secrets through dream-sharing tech.",
                        "",
                    )
                    m2 = insert_movie(
                        cur,
                        "Interstellar",
                        2014,
                        "Christopher Nolan",
                        "Matthew McConaughey, Anne Hathaway, Jessica Chastain",
                        "A team travels through a wormhole in space in an attempt to ensure humanity's survival.",
                        "",
                    )
                    seeded["movies_added"] += 2

                    # favorites: only if favorites table empty
                    if favorites_count == 0:
                        insert_favorite(cur, u1, m1)
                        insert_favorite(cur, u1, m2)
                        seeded["favorites_added"] += 2

                        insert_favorite(cur, u1, m1)
                        insert_favorite(cur, u1, m2)
                        seeded["favorites_added"] += 2
        return response(200, {"message": "Seed completed (no-op if not empty)", "details": seeded})
    except Exception as e:
        return response(500, {"error": str(e)})
