# ─── Outputs ──────────────────────────────────────────────────────────────────
# Los outputs muestran los valores importantes al terminar `terraform apply`.
# También los usa el CI/CD para saber a qué URL apuntar el frontend.

output "frontend_url" {
  description = "URL del frontend (CloudFront) — va en VITE_API_URL del build"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "backend_url" {
  description = "URL del backend (ALB) — va en VITE_API_URL del build del frontend"
  value       = "http://${aws_lb.backend.dns_name}"
}

output "ecr_repository_url" {
  description = "URL del repositorio ECR — se usa en el CI/CD para hacer docker push"
  value       = aws_ecr_repository.backend.repository_url
}

output "s3_bucket_name" {
  description = "Nombre del bucket S3 — se usa en el CI/CD para hacer aws s3 sync"
  value       = aws_s3_bucket.frontend.bucket
}

output "cloudfront_distribution_id" {
  description = "ID de la distribución CloudFront — se usa para invalidar caché tras deploy"
  value       = aws_cloudfront_distribution.frontend.id
}

output "rds_endpoint" {
  description = "Endpoint de RDS — referencia para verificar conectividad"
  value       = aws_db_instance.postgres.address
  sensitive   = true
}
