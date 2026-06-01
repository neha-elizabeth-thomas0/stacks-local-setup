store "varset" "tokens" {
  name       = "AwsCreds"
  category = "env"
}

deployment "dev" {
  inputs = {
    environment   = "dev"
    region        = "us-east-1"
    access_key    = store.varset.tokens.AWS_ACCESS_KEY_ID
    secret_key    = store.varset.tokens.AWS_SECRET_ACCESS_KEY
    session_token = store.varset.tokens.AWS_SESSION_TOKEN

  }
  destroy = true
}

deployment "prod" {
  inputs = {
    environment   = "prod"
    region        = "us-west-2"
    access_key    = store.varset.tokens.AWS_ACCESS_KEY_ID
    secret_key    = store.varset.tokens.AWS_SECRET_ACCESS_KEY
    session_token = store.varset.tokens.AWS_SESSION_TOKEN

  }
  destroy = true
}

