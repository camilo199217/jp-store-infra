# ─── Security Groups ──────────────────────────────────────────────────────────
# Los security groups son el firewall de AWS — definen qué tráfico entra y sale
# de cada recurso. Principio de mínimo privilegio: solo abrir lo estrictamente necesario.

# ── ALB: recibe tráfico HTTP/HTTPS desde internet ─────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${var.project}-sg-alb"
  description = "Allow HTTP and HTTPS inbound traffic from internet to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-sg-alb"
    Environment = var.environment
  }
}

# ── ECS: solo acepta tráfico proveniente del ALB ──────────────────────────────
resource "aws_security_group" "ecs" {
  name        = "${var.project}-sg-ecs"
  description = "Allow traffic to NestJS container only from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Traffic from ALB to backend port"
    from_port       = var.backend_port
    to_port         = var.backend_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound traffic - needed for payment gateway, RDS, SSM, ECR"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-sg-ecs"
    Environment = var.environment
  }
}

# ── RDS: solo acepta tráfico proveniente de ECS ───────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${var.project}-sg-rds"
  description = "Allow PostgreSQL connections only from ECS containers"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-sg-rds"
    Environment = var.environment
  }
}
