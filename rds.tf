# ─── RDS PostgreSQL ───────────────────────────────────────────────────────────
# Base de datos administrada. AWS se encarga de backups, parches y failover.
# Usamos db.t3.micro para mantener el costo bajo (~$15/mes).

# Subnet group: le dice a RDS en qué subnets puede vivir (usamos las privadas)
resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name        = "${var.project}-db-subnet-group"
    Environment = var.environment
  }
}

resource "aws_db_instance" "postgres" {
  identifier = "${var.project}-db"

  # Motor y versión
  engine         = "postgres"
  engine_version = "16.3"
  instance_class = "db.t3.micro"

  # Almacenamiento
  allocated_storage     = 20
  max_allocated_storage = 50   # autoscaling hasta 50 GB si se necesita
  storage_type          = "gp2"
  storage_encrypted     = true

  # Credenciales
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Red y seguridad
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false  # nunca expuesta a internet

  # Backups automáticos — retención de 7 días
  backup_retention_period = 7
  backup_window           = "03:00-04:00"  # UTC (madrugada Colombia)
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # En producción real esto debería ser false — aquí lo dejamos true para
  # poder borrar fácilmente durante la prueba técnica sin bloqueos
  deletion_protection      = false
  skip_final_snapshot      = true

  tags = {
    Name        = "${var.project}-db"
    Environment = var.environment
  }
}
