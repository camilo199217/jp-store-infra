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

# ── Security Headers Policy ───────────────────────────────────────────────────
# Adjunta headers de seguridad OWASP a todas las respuestas de CloudFront.
# Se aplica tanto al behavior del frontend (S3) como al del backend (ALB/API).
resource "aws_cloudfront_response_headers_policy" "security" {
  name    = "${var.project}-security-headers"
  comment = "OWASP security headers for ${var.project}"

  security_headers_config {
    # Impide que el navegador adivine el Content-Type (sniffing attacks)
    content_type_options {
      override = true
    }

    # Impide que la página se cargue dentro de un iframe (clickjacking)
    frame_options {
      frame_option = "DENY"
      override     = true
    }

    # Fuerza HTTPS durante 1 año incluyendo subdominios (HSTS)
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    # Controla cuánta información de referencia se envía en las solicitudes
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    # CSP: solo permite recursos del mismo origen + Wompi y fuentes de Google
    content_security_policy {
      content_security_policy = "default-src 'self'; script-src 'self' 'unsafe-inline' https://checkout.wompi.co; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: https:; connect-src 'self' https://api.wompi.co https://sandbox.wompi.co; frame-src https://checkout.wompi.co; object-src 'none'; base-uri 'self';"
      override                = true
    }

    # Controla las características del navegador disponibles para la página
    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }
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

  # Segundo origen: el ALB del backend — CloudFront hace el puente HTTPS→HTTP
  origin {
    domain_name = aws_lb.backend.dns_name
    origin_id   = "alb-backend"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Behavior para /api/* — sin cache, reenvía headers y query strings al ALB
  ordered_cache_behavior {
    path_pattern                   = "/api/*"
    allowed_methods                = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods                 = ["GET", "HEAD"]
    target_origin_id               = "alb-backend"
    viewer_protocol_policy         = "redirect-to-https"
    response_headers_policy_id     = aws_cloudfront_response_headers_policy.security.id

    forwarded_values {
      query_string = true
      headers      = ["Origin", "Authorization", "Content-Type", "Accept"]
      cookies { forward = "none" }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  default_cache_behavior {
    allowed_methods                = ["GET", "HEAD", "OPTIONS"]
    cached_methods                 = ["GET", "HEAD"]
    target_origin_id               = "s3-frontend"
    viewer_protocol_policy         = "redirect-to-https"
    response_headers_policy_id     = aws_cloudfront_response_headers_policy.security.id

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
