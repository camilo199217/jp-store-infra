# ─── IAM Roles para ECS ───────────────────────────────────────────────────────
# ECS necesita dos roles distintos:
#
# 1. Execution Role — lo usa el agente de ECS para:
#    - Descargar la imagen desde ECR
#    - Leer secrets de SSM Parameter Store
#    - Enviar logs a CloudWatch
#
# 2. Task Role — lo usa el CONTENEDOR en tiempo de ejecución para:
#    - Llamar a otros servicios de AWS si el backend lo necesitara
#    (En este proyecto no se usa directamente, pero es buena práctica tenerlo)

# ── Execution Role ─────────────────────────────────────────────────────────────
resource "aws_iam_role" "ecs_execution" {
  name = "${var.project}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project}-ecs-execution-role"
    Environment = var.environment
  }
}

# Política gestionada por AWS que cubre ECR + CloudWatch Logs
resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Permiso adicional para leer parámetros de SSM (las variables de entorno del backend)
resource "aws_iam_role_policy" "ecs_execution_ssm" {
  name = "${var.project}-ecs-execution-ssm"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project}/*"
      }
    ]
  })
}

# ── Task Role ──────────────────────────────────────────────────────────────────
resource "aws_iam_role" "ecs_task" {
  name = "${var.project}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project}-ecs-task-role"
    Environment = var.environment
  }
}
