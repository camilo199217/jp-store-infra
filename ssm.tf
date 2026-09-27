# ─── SSM Parameter Store ──────────────────────────────────────────────────────
# Guardamos las variables de entorno del backend de forma segura.
# Los parámetros tipo "SecureString" van cifrados con KMS.
# ECS los inyecta como variables de entorno al contenedor en tiempo de arranque —
# nunca quedan en el código ni en el Dockerfile.

locals {
  ssm_prefix = "/${var.project}"
}

# ── Variables no sensibles (String) ───────────────────────────────────────────

resource "aws_ssm_parameter" "node_env" {
  name  = "${local.ssm_prefix}/NODE_ENV"
  type  = "String"
  value = "production"
}

resource "aws_ssm_parameter" "port" {
  name  = "${local.ssm_prefix}/PORT"
  type  = "String"
  value = tostring(var.backend_port)
}

resource "aws_ssm_parameter" "frontend_url" {
  name  = "${local.ssm_prefix}/FRONTEND_URL"
  type  = "String"
  value = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

resource "aws_ssm_parameter" "base_fee" {
  name  = "${local.ssm_prefix}/BASE_FEE"
  type  = "String"
  value = "1500000"
}

resource "aws_ssm_parameter" "delivery_fee" {
  name  = "${local.ssm_prefix}/DELIVERY_FEE"
  type  = "String"
  value = "890000"
}

resource "aws_ssm_parameter" "payment_api_url" {
  name  = "${local.ssm_prefix}/PAYMENT_API_URL"
  type  = "String"
  value = "https://api-sandbox.co.uat.wompi.dev/v1"
}

resource "aws_ssm_parameter" "db_host" {
  name  = "${local.ssm_prefix}/DB_HOST"
  type  = "String"
  value = aws_db_instance.postgres.address
}

resource "aws_ssm_parameter" "db_port" {
  name  = "${local.ssm_prefix}/DB_PORT"
  type  = "String"
  value = "5432"
}

resource "aws_ssm_parameter" "db_name" {
  name  = "${local.ssm_prefix}/DB_NAME"
  type  = "String"
  value = var.db_name
}

resource "aws_ssm_parameter" "db_user" {
  name  = "${local.ssm_prefix}/DB_USER"
  type  = "String"
  value = var.db_username
}

# ── Variables sensibles (SecureString — cifradas con KMS) ─────────────────────

resource "aws_ssm_parameter" "db_password" {
  name  = "${local.ssm_prefix}/DB_PASS"
  type  = "SecureString"
  value = var.db_password
}

resource "aws_ssm_parameter" "payment_public_key" {
  name  = "${local.ssm_prefix}/PAYMENT_PUBLIC_KEY"
  type  = "SecureString"
  value = "pub_stagtest_g2u0HQd3ZMh05hsSgTS2lUV8t3s4mOt7"
}

resource "aws_ssm_parameter" "payment_private_key" {
  name  = "${local.ssm_prefix}/PAYMENT_PRIVATE_KEY"
  type  = "SecureString"
  value = "prv_stagtest_5i0ZGIGiFcDQifYsXxvsny7Y37tKqFWg"
}

resource "aws_ssm_parameter" "payment_integrity_key" {
  name  = "${local.ssm_prefix}/PAYMENT_INTEGRITY_KEY"
  type  = "SecureString"
  value = "stagtest_integrity_nAIBuqayW70XpUqJS4qf4STYiISd89Fp"
}

resource "aws_ssm_parameter" "payment_events_key" {
  name  = "${local.ssm_prefix}/PAYMENT_EVENTS_KEY"
  type  = "SecureString"
  value = "stagtest_events_2PDUmhMywUkvb1LvxYnayFbmofT7w39N"
}
