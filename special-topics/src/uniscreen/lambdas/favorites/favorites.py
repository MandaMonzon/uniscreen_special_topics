import json
import os
from typing import Optional, Tuple, List, Dict

import boto3
import pg8000


def response(status_code: int, body: dict):
  return {
    "statusCode": status_code,
    "headers": {"Content-Type": "application/json"},
    "body": json.dumps(body),
    "isBase64Encoded": False,
  }


def get_claims(event) -> dict:
  try:
    return (event.get("requestContext") or {}).get("authorizer", {}).get("claims") or {}
  except Exception:
    return {}


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


def get_or_create_user(conn, email: str) -> int:
  """
  Garante a existência de um usuário no schema public.users (colunas: email, password_hash).
  Retorna o id do usuário.
  """
  with conn.cursor() as cur:
    cur.execute("SELECT id FROM public.users WHERE email = %s", (email,))
    row = cur.fetchone()
    if row:
      return int(row[0])

    # Cria usuário com password_hash placeholder
    cur.execute(
      """
      INSERT INTO public.users (email, password_hash)
      VALUES (%s, %s)
      RETURNING id
      """,
      (email, "cognito"),
    )
    new_row = cur.fetchone()
    return int(new_row[0])


def list_favorites(conn, email: str) -> List[Dict]:
  """
  Lista favoritos do usuário (por email), retornando metadados do filme.
  """
  with conn.cursor() as cur:
    cur.execute(
      """
      SELECT m.id, m.title, m.year, m.director, m.actors, m.plot, m.poster_url
      FROM public.favorites f
      JOIN public.users u ON u.id = f.user_id
      JOIN public.movies m ON m.id = f.movie_id
      WHERE u.email = %s
      ORDER BY m.title
      """,
      (email,),
    )
    items = []
    for row in cur.fetchall() or []:
      items.append({
        "movie_id": row[0],
        "title": row[1],
        "year": row[2],
        "director": row[3],
        "actors": row[4],
        "plot": row[5],
        "poster_url": row[6],
      })
    return items


def add_favorite(conn, email: str, movie_id: int) -> bool:
  """
  Adiciona favorito (ignora se já existir).
  Retorna True se inseriu, False se já existia.
  """
  user_id = get_or_create_user(conn, email)
  with conn.cursor() as cur:
    # Usa ON CONFLICT para idempotência (constraint UNIQUE (user_id, movie_id))
    cur.execute(
      """
      INSERT INTO public.favorites (user_id, movie_id)
      VALUES (%s, %s)
      ON CONFLICT (user_id, movie_id) DO NOTHING
      """,
      (user_id, movie_id),
    )
    # Não há rowcount confiável para INSERT ... DO NOTHING em todos drivers; valida com SELECT
    cur.execute(
      "SELECT 1 FROM public.favorites WHERE user_id = %s AND movie_id = %s",
      (user_id, movie_id),
    )
    return bool(cur.fetchone())


def remove_favorite(conn, email: str, movie_id: int) -> int:
  """
  Remove favorito. Retorna número de linhas removidas (0 ou 1).
  """
  with conn.cursor() as cur:
    cur.execute("SELECT id FROM public.users WHERE email = %s", (email,))
    row = cur.fetchone()
    if not row:
      return 0
    user_id = int(row[0])
    cur.execute(
      "DELETE FROM public.favorites WHERE user_id = %s AND movie_id = %s",
      (user_id, movie_id),
    )
    # pg8000: rowcount disponível
    return cur.rowcount or 0


def parse_body(event) -> dict:
  body = event.get("body")
  if isinstance(body, str):
    try:
      return json.loads(body or "{}")
    except Exception:
      return {}
  return body or {}


def lambda_handler(event, context):
  """
  Protected endpoint (/favorites) behind Cognito User Pool Authorizer.
  - GET: list favorites for the authenticated user
  - POST: add or remove a favorite (expects JSON: {"movie_id": number, "action": "add"|"remove"})
          se "action" não enviado, assume "add"
  """
  try:
    method = event.get("httpMethod", "GET")
    claims = get_claims(event)
    user_sub = claims.get("sub")
    user_email = claims.get("email")
    if not user_email:
      # Fallback se email não estiver presente no token
      if user_sub:
        user_email = f"{user_sub}@cognito.local"
      else:
        return response(401, {"error": "Unauthorized: missing user claims"})

    host, user, password, port, database = get_rds_credentials()
    conn = pg8000.connect(user=user, password=password, host=host, port=port, database=database, ssl_context=True)
    try:
      if method == "GET":
        items = list_favorites(conn, user_email)
        return response(200, {"items": items})

      if method == "POST":
        data = parse_body(event)
        action = (data.get("action") or "add").lower()
        movie_id = data.get("movie_id")
        if not isinstance(movie_id, int):
          # Aceita string numérica
          try:
            movie_id = int(movie_id)
          except Exception:
            return response(400, {"error": "Missing or invalid movie_id"})

        if action == "remove":
          removed = remove_favorite(conn, user_email, movie_id)
          conn.commit()
          return response(200, {"message": "Favorite removed" if removed else "Favorite not found", "removed": removed})

        # default: add
        added_present = add_favorite(conn, user_email, movie_id)
        conn.commit()
        return response(201, {"message": "Favorite added", "exists": added_present})

      return response(405, {"error": f"Method {method} not allowed"})
    finally:
      try:
        conn.close()
      except Exception:
        pass
  except Exception as e:
    return response(500, {"error": str(e)})
