# ─── Application Load Balancer ────────────────────────────────────────────────
# El ALB recibe el tráfico de internet y lo distribuye a los contenedores ECS.
# Vive en las subnets públicas — es el único punto de entrada al backend.

resource "aws_lb" "backend" {
  name               = "${var.project}-alb"
  internal           = false  # público, accesible desde internet
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name        = "${var.project}-alb"
    Environment = var.environment
  }
}

# ── Target Group ───────────────────────────────────────────────────────────────
# Define cómo el ALB envía tráfico a los contenedores y cómo comprueba su salud.
resource "aws_lb_target_group" "backend" {
  name        = "${var.project}-tg"
  port        = var.backend_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"  # necesario para Fargate (no hay instancias EC2)

  health_check {
    enabled             = true
    path                = "/api/v1/products"  # el mismo endpoint que usa el Dockerfile
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name        = "${var.project}-tg"
    Environment = var.environment
  }
}

# ── Listener HTTP ──────────────────────────────────────────────────────────────
# Escucha en el puerto 80 y reenvía al target group.
# Para producción real agregaríamos HTTPS (443) con un certificado ACM.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.backend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}
