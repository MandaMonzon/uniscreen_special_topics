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

    client_id = os.environ.get("USER_POOL_CLIENT_ID")
    if not client_id:
      return response(500, {"error": "Cognito environment not configured"})

    # Cognito USER_PASSWORD_AUTH (with app client that allows this flow)
    auth_result = cognito.initiate_auth(
      ClientId=client_id,
      AuthFlow="USER_PASSWORD_AUTH",
      AuthParameters={
        "USERNAME": email,
        "PASSWORD": password,
      },
    )

    tokens = auth_result.get("AuthenticationResult", {})
    return response(200, {
      "id_token": tokens.get("IdToken"),
      "access_token": tokens.get("AccessToken"),
      "refresh_token": tokens.get("RefreshToken"),
      "token_type": tokens.get("TokenType"),
      "expires_in": tokens.get("ExpiresIn"),
    })
  except cognito.exceptions.NotAuthorizedException:
    return response(401, {"error": "Invalid credentials"})
  except cognito.exceptions.UserNotConfirmedException:
    return response(403, {"error": "User not confirmed"})
  except Exception as e:
    return response(500, {"error": str(e)})
