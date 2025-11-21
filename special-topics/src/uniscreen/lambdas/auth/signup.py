import json
import os
import boto3

cognito = boto3.client("cognito-idp")


def response(status_code: int, body: dict):
  return {
    "statusCode": status_code,
    "headers": {"Content-Type": "application/json"},
    "body": json.dumps(body),
    "isBase64Encoded": False,
  }


def lambda_handler(event, context):
  # Expect JSON body: { "email": "...", "password": "..." }
  try:
    body = event.get("body")
    if isinstance(body, str):
      body = json.loads(body or "{}")
    elif body is None:
      body = {}

    email = body.get("email")
    password = body.get("password")

    if not email or not password:
      return response(400, {"error": "Missing email or password"})

    user_pool_id = os.environ.get("USER_POOL_ID")
    client_id = os.environ.get("USER_POOL_CLIENT_ID")
    if not user_pool_id or not client_id:
      return response(500, {"error": "Cognito environment not configured"})

    # Use Cognito SignUp flow (client side). This will create a user in the user pool.
    # Confirmation may be required depending on pool settings; for simplicity assume email auto-verified rules.
    cognito.sign_up(
      ClientId=client_id,
      Username=email,
      Password=password,
      UserAttributes=[{"Name": "email", "Value": email}],
    )

    return response(200, {"message": "Signup initiated. Check email if confirmation is required."})
  except cognito.exceptions.UsernameExistsException:
    return response(409, {"error": "User already exists"})
  except Exception as e:
    return response(500, {"error": str(e)})
