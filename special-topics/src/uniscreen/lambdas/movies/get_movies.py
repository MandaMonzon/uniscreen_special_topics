import json
import os
import urllib.parse
import urllib.request
from typing import Optional, Tuple

import boto3
import pg8000


s3 = boto3.client("s3")


def response(status_code: int, body: dict):
  return {
    "statusCode": status_code,
    "headers": {"Content-Type": "application/json"},
    "body": json.dumps(body),
    "isBase64Encoded": False,
  }


def fetch_omdb(title: str, api_key: str):
  qs = urllib.parse.urlencode({"t": title, "apikey": api_key})
  url = f"https://www.omdbapi.com/?{qs}"
  with urllib.request.urlopen(url, timeout=15) as resp:
    data = resp.read()
    return json.loads(data.decode("utf-8"))


def download_bytes(url: str) -> bytes:
  with urllib.request.urlopen(url, timeout=20) as resp:
    return resp.read()


def s3_public_url(bucket: str, key: str) -> str:
  # Com bucket policy pública (s3:GetObject) habilitada, a URL direta funciona
  # Ex: https://<bucket>.s3.amazonaws.com/<key>
  return f"https://{bucket}.s3.amazonaws.com/{key}"


def upload_poster_to_s3(bucket: str, key: str, data: bytes, content_type: str = "image/jpeg") -> str:
  # Não define ACL pública explicitamente; a bucket policy cuidará do acesso público
  s3.put_object(Bucket=bucket, Key=key, Body=data, ContentType=content_type)
  return s3_public_url(bucket, key)


def parse_year(raw_year: Optional[str]) -> Optional[int]:
  if not raw_year or raw_year == "N/A":
    return None
  # OMDb pode retornar "1999" ou "1999–" etc. Extrai os dígitos iniciais.
  digits = ""
  for ch in raw_year:
    if ch.isdigit():
      digits += ch
    else:
      break
  try:
    return int(digits) if digits else None
  except Exception:
    return None


def get_rds_credentials() -> Tuple[str, str, str, int, str]:
  """
  Retorna (host, user, password, port, database) a partir das variáveis e Secret do RDS.
  Espera-se que o Secret (RDS_SECRET_ID) tenha o formato padrão do AWS RDS:
   {"username":"...", "password":"...", "engine":"postgres", "host":"...", "port":5432, "dbname":"..."}
  """
  region = os.environ.get("REGION") or os.environ.get("AWS_REGION") or "us-east-2"
  secret_id = os.environ.get("RDS_SECRET_ID")
  host_env = os.environ.get("DB_ENDPOINT")
  port_env = os.environ.get("DB_PORT")
  db_env = os.environ.get("DB_NAME")

  if not secret_id:
    raise RuntimeError("Missing RDS_SECRET_ID environment variable")

  sm = boto3.client("secretsmanager", region_name=region)
  sec = sm.get_secret_value(SecretId=secret_id)
  secret_str = sec.get("SecretString") or "{}"
  secret = json.loads(secret_str)

  username = secret.get("username")
  password = secret.get("password")
  host = host_env or secret.get("host")
  port = int(port_env or secret.get("port") or 5432)
  database = db_env or secret.get("dbname")

  if not (username and password and host and database):
    raise RuntimeError("Incomplete RDS credentials (username/password/host/database)")

  return host, username, password, port, database


def upsert_movie(conn, title: str, year: Optional[int], director: Optional[str], actors: Optional[str],
                 plot: Optional[str], poster_url: Optional[str]) -> dict:
  """
  Faz upsert com base em (title, year). Se existir, atualiza; senão, insere.
  Como não há UNIQUE (title, year) no schema, faz SELECT antes.
  Retorna o registro (id, title, year, director, actors, plot, poster_url).
  """
  with conn.cursor() as cur:
    # Evitar parâmetro None sem tipo (erro 42P18) em consultas
    if year is None:
      cur.execute(
        """
        SELECT id FROM public.movies
        WHERE title = %s AND year IS NULL
        """,
        (title,),
      )
    else:
      cur.execute(
        """
        SELECT id FROM public.movies
        WHERE title = %s AND year = %s
        """,
        (title, year),
      )
    row = cur.fetchone()

    if row:
      movie_id = row[0]
      cur.execute(
        """
        UPDATE public.movies
        SET director = %s, actors = %s, plot = %s, poster_url = %s
        WHERE id = %s
        RETURNING id, title, year, director, actors, plot, poster_url
        """,
        (director, actors, plot, poster_url, movie_id),
      )
      res = cur.fetchone()
    else:
      if year is None:
        cur.execute(
          """
          INSERT INTO public.movies (title, year, director, actors, plot, poster_url)
          VALUES (%s, NULL::integer, %s, %s, %s, %s)
          RETURNING id, title, year, director, actors, plot, poster_url
          """,
          (title, director, actors, plot, poster_url),
        )
      else:
        cur.execute(
          """
          INSERT INTO public.movies (title, year, director, actors, plot, poster_url)
          VALUES (%s, %s, %s, %s, %s, %s)
          RETURNING id, title, year, director, actors, plot, poster_url
          """,
          (title, year, director, actors, plot, poster_url),
        )
      res = cur.fetchone()

  return {
    "id": res[0],
    "title": res[1],
    "year": res[2],
    "director": res[3],
    "actors": res[4],
    "plot": res[5],
    "poster_url": res[6],
  }

def list_movies(conn) -> list[dict]:
  with conn.cursor() as cur:
    cur.execute(
      """
      SELECT id, title, year, director
      FROM public.movies
      ORDER BY id
      """
    )
    rows = cur.fetchall()
  return [{"id": r[0], "title": r[1], "year": r[2], "director": r[3]} for r in rows]


def get_title_from_event(event) -> Optional[str]:
  # Suporta POST (body JSON {"title": "..."})
  method = event.get("httpMethod", "GET")
  if method == "POST":
    body = event.get("body")
    if isinstance(body, str):
      try:
        data = json.loads(body or "{}")
      except Exception:
        data = {}
    else:
      data = body or {}
    return data.get("title")

  # Fallback GET com ?title=...
  params = event.get("queryStringParameters") or {}
  return params.get("title")


def get_omdb_api_key_from_secret(region: str, omdb_secret_arn: str) -> str:
  sm = boto3.client("secretsmanager", region_name=region)
  sec = sm.get_secret_value(SecretId=omdb_secret_arn)
  val = sec.get("SecretString") or "{}"
  api = json.loads(val)
  return api.get("OMDB_API_KEY", "")


def lambda_handler(event, context):
  try:
    title = get_title_from_event(event)
    method = event.get("httpMethod", "GET")
    if method == "GET" and not title:
      # Listar filmes diretamente do RDS
      host, user, password, port, database = get_rds_credentials()
      conn = pg8000.connect(user=user, password=password, host=host, port=port, database=database, ssl_context=True)
      try:
        movies = list_movies(conn)
      finally:
        try:
          conn.close()
        except Exception:
          pass
      return response(200, {"movies": movies})

    if not title:
      return response(400, {"error": "Missing 'title' (POST JSON body or query parameter)"})

    posters_bucket = os.environ.get("POSTERS_BUCKET")
    region = os.environ.get("REGION") or os.environ.get("AWS_REGION") or "us-east-2"
    omdb_secret_arn = os.environ.get("OMDB_SECRET_ARN", "")

    if not posters_bucket:
      return response(500, {"error": "Lambda environment not configured (POSTERS_BUCKET)"})

    # OMDb API key
    if not omdb_secret_arn:
      return response(500, {"error": "Missing OMDb API key secret ARN (OMDB_SECRET_ARN)"})
    api_key = get_omdb_api_key_from_secret(region, omdb_secret_arn)
    if not api_key:
      return response(500, {"error": "Missing OMDb API key in Secrets Manager"})

    # Fetch OMDb
    omdb = fetch_omdb(title, api_key)
    if not omdb or omdb.get("Response") != "True":
      return response(404, {"error": "Movie not found on OMDb", "raw": omdb})

    # Poster
    poster_url_src = omdb.get("Poster")
    uploaded_poster_url = None
    if poster_url_src and poster_url_src != "N/A":
      try:
        content = download_bytes(poster_url_src)
        safe_title = urllib.parse.quote_plus(omdb.get("Title") or title)
        key = f"posters/{safe_title}.jpg"
        uploaded_poster_url = upload_poster_to_s3(posters_bucket, key, content)
      except Exception as e:
        uploaded_poster_url = None  # Não bloquear fluxo principal

    # Dados principais
    title_out = omdb.get("Title") or title
    year_out = parse_year(omdb.get("Year"))
    director = omdb.get("Director") if omdb.get("Director") != "N/A" else None

    # Normalização de "actors": garantir string (separada por vírgulas) ou None
    actors_raw = omdb.get("Actors")
    if isinstance(actors_raw, list):
      actors = ", ".join([str(a) for a in actors_raw if a and a != "N/A"]).strip() or None
    elif isinstance(actors_raw, str):
      actors = None if actors_raw.strip() == "" or actors_raw == "N/A" else actors_raw
    else:
      actors = None

    plot = omdb.get("Plot") if omdb.get("Plot") != "N/A" else None
    poster_final = uploaded_poster_url or (poster_url_src if poster_url_src != "N/A" else None)

    # Persistência no RDS (pg8000)
    host, user, password, port, database = get_rds_credentials()
    conn = pg8000.connect(user=user, password=password, host=host, port=port, database=database, ssl_context=True)
    try:
      movie_row = upsert_movie(conn, title_out, year_out, director, actors, plot, poster_final)
      conn.commit()
    finally:
      try:
        conn.close()
      except Exception:
        pass

    return response(200, {"message": "Movie upserted", "movie": movie_row})
  except Exception as e:
    return response(500, {"error": str(e)})
