# ─── ECS Fargate (Backend NestJS) ─────────────────────────────────────────────
# Fargate es serverless para contenedores — no hay que gestionar servidores EC2.
# AWS cobra solo por el tiempo que el contenedor está corriendo.

# ── CloudWatch Log Group ───────────────────────────────────────────────────────
# Los logs del contenedor van aquí — visibles en la consola de AWS
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.project}-backend"
  retention_in_days = 7  # borramos logs viejos para no acumular costo

  tags = {
    Name        = "${var.project}-backend-logs"
    Environment = var.environment
  }
}

# ── ECS Cluster ───────────────────────────────────────────────────────────────
resource "aws_ecs_cluster" "main" {
  name = "${var.project}-cluster"

  tags = {
    Name        = "${var.project}-cluster"
    Environment = var.environment
  }
}

# ── Task Definition ────────────────────────────────────────────────────────────
# Define el contenedor: imagen, CPU, memoria, variables de entorno y logs.
# Las variables sensibles se leen de SSM en tiempo de arranque (secrets).
resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256   # 0.25 vCPU — mínimo de Fargate
  memory                   = 512   # 0.5 GB — mínimo viable para NestJS

  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = var.backend_image != "" ? var.backend_image : "${aws_ecr_repository.backend.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = var.backend_port
          protocol      = "tcp"
        }
      ]

      # Variables no sensibles — van directo en la task definition
      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "PORT",     value = tostring(var.backend_port) },
      ]

      # Variables sensibles — ECS las lee de SSM al arrancar el contenedor
      secrets = [
        { name = "DB_HOST",              valueFrom = aws_ssm_parameter.db_host.arn },
        { name = "DB_PORT",              valueFrom = aws_ssm_parameter.db_port.arn },
        { name = "DB_NAME",              valueFrom = aws_ssm_parameter.db_name.arn },
        { name = "DB_USER",              valueFrom = aws_ssm_parameter.db_user.arn },
        { name = "DB_PASS",              valueFrom = aws_ssm_parameter.db_password.arn },
        { name = "FRONTEND_URL",         valueFrom = aws_ssm_parameter.frontend_url.arn },
        { name = "BASE_FEE",             valueFrom = aws_ssm_parameter.base_fee.arn },
        { name = "DELIVERY_FEE",         valueFrom = aws_ssm_parameter.delivery_fee.arn },
        { name = "PAYMENT_API_URL",        valueFrom = aws_ssm_parameter.payment_api_url.arn },
        { name = "PAYMENT_PUBLIC_KEY",     valueFrom = aws_ssm_parameter.payment_public_key.arn },
        { name = "PAYMENT_PRIVATE_KEY",    valueFrom = aws_ssm_parameter.payment_private_key.arn },
        { name = "PAYMENT_INTEGRITY_KEY",  valueFrom = aws_ssm_parameter.payment_integrity_key.arn },
        { name = "PAYMENT_EVENTS_KEY",     valueFrom = aws_ssm_parameter.payment_events_key.arn },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget -qO- http://localhost:${var.backend_port}/api/v1/products || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name        = "${var.project}-backend-task"
    Environment = var.environment
  }
}

# ── ECS Service ───────────────────────────────────────────────────────────────
# Mantiene siempre 1 tarea corriendo. Si el contenedor muere, ECS lo reinicia.
resource "aws_ecs_service" "backend" {
  name            = "${var.project}-backend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # El contenedor vive en subnets públicas (sin NAT Gateway — reduce costo)
  # y tiene IP pública para poder llamar al payment gateway y descargar la imagen de ECR
  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = var.backend_port
  }

  depends_on = [aws_lb_listener.http]

  # Evita que Terraform destruya el servicio si cambia la task definition
  # (el CI/CD se encarga de los deploys de nuevas versiones)
  lifecycle {
    ignore_changes = [task_definition]
  }

  tags = {
    Name        = "${var.project}-backend-service"
    Environment = var.environment
  }
}
