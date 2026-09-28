# jp-store-infra

Infraestructura AWS definida con Terraform para el proyecto jp-store.

## Arquitectura

```
Internet → CloudFront → S3 (frontend SPA)
                     ↘ ALB → ECS Fargate (backend NestJS)
                                    ↘ RDS PostgreSQL
```

| Recurso | Servicio AWS | Propósito |
|---|---|---|
| Frontend | S3 + CloudFront | SPA estática con CDN global |
| Backend | ECS Fargate + ALB | API NestJS en contenedor |
| Base de datos | RDS PostgreSQL | Datos transaccionales |
| Imágenes | ECR | Registro privado de Docker |
| Secretos | SSM Parameter Store | Variables sensibles cifradas |

## Seguridad

### Headers HTTP (CloudFront Response Headers Policy)

Todos los responses incluyen los siguientes headers de seguridad OWASP:

| Header | Valor | Protege contra |
|---|---|---|
| `X-Content-Type-Options` | `nosniff` | MIME-type sniffing |
| `X-Frame-Options` | `DENY` | Clickjacking |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains; preload` | Downgrade a HTTP |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Fuga de URLs sensibles |
| `Content-Security-Policy` | Solo orígenes permitidos + Wompi | XSS / inyección de scripts |
| `X-XSS-Protection` | `1; mode=block` | XSS legacy browsers |

### Otras medidas

- Bucket S3 privado — acceso exclusivo vía OAC (Origin Access Control)
- `redirect-to-https` en todos los behaviors
- Security Groups restrictivos: solo el ALB accede al puerto del contenedor
- Secrets en SSM Parameter Store (no en variables de entorno en texto plano)

## URLs desplegadas

| Recurso | URL |
|---|---|
| Frontend (CloudFront) | https://d1ooypu8bqmie2.cloudfront.net |
| API Docs (Swagger) | https://d1ooypu8bqmie2.cloudfront.net/api/docs |
| Backend (ALB interno) | http://jp-store-alb-1031393668.us-east-1.elb.amazonaws.com |

> El ALB no tiene HTTPS propio — todo el tráfico externo entra por CloudFront que provee TLS.

## Uso

```bash
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### Variables requeridas (`terraform.tfvars`)

```hcl
project     = "jp-store"
environment = "production"
region      = "us-east-1"
db_password = "<secret>"
```
