# ─── S3 + CloudFront (Frontend SPA) ──────────────────────────────────────────
# El frontend compilado (archivos estáticos de Vite) se sube a S3.
# CloudFront actúa como CDN: sirve los archivos desde edge locations cercanas
# al usuario, con caché y HTTPS incluido sin costo adicional.

# ── Bucket S3 ─────────────────────────────────────────────────────────────────
resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project}-frontend"

  tags = {
    Name        = "${var.project}-frontend"
    Environment = var.environment
  }
}

# Bloquear todo acceso público directo al bucket —
# el único acceso permitido es a través de CloudFront (OAC)
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── Origin Access Control ──────────────────────────────────────────────────────
# Le permite a CloudFront acceder al bucket privado en nombre del usuario.
# Es el reemplazo moderno del OAI (Origin Access Identity).
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ── CloudFront Distribution ────────────────────────────────────────────────────
resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "${var.project} frontend"

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "s3-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-frontend"
    viewer_protocol_policy = "redirect-to-https"  # fuerza HTTPS — bonus points OWASP

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    # Cache largo para assets con hash (JS, CSS) — el nginx.conf ya tiene esto,
    # pero CloudFront también necesita saberlo para no revalidar en cada request
    min_ttl     = 0
    default_ttl = 86400    # 1 día
    max_ttl     = 31536000 # 1 año
  }

  # SPA fallback: cualquier ruta que no exista como archivo devuelve index.html
  # con código 200 para que Vue Router tome el control
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true  # HTTPS gratis con dominio de CloudFront
  }

  tags = {
    Name        = "${var.project}-cdn"
    Environment = var.environment
  }
}

# ── Política del bucket: solo CloudFront puede leer ───────────────────────────
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontAccess"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
          }
        }
      }
    ]
  })
}
