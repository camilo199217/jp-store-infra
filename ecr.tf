# ─── ECR (Elastic Container Registry) ────────────────────────────────────────
# Es el registro privado de Docker en AWS — como Docker Hub pero dentro de tu cuenta.
# ECS descarga la imagen del backend desde aquí para correr los contenedores.

resource "aws_ecr_repository" "backend" {
  name                 = "${var.project}-backend"
  image_tag_mutability = "MUTABLE"  # permite sobrescribir el tag "latest"

  # Escaneo automático de vulnerabilidades en cada push
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project}-backend"
    Environment = var.environment
  }
}

# Política de ciclo de vida — borra imágenes viejas automáticamente.
# Solo conserva las últimas 5 imágenes para no acumular almacenamiento.
resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Conservar solo las últimas 5 imágenes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
