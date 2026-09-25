# ─── Variables globales ────────────────────────────────────────────────────────
# Centraliza los valores que se reutilizan en todos los archivos .tf.
# Para cambiar de entorno o región, solo se modifica aquí (o se pasa con -var).

variable "aws_region" {
  description = "Región de AWS donde se despliega todo"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Nombre del proyecto — se usa como prefijo en todos los recursos"
  type        = string
  default     = "jp-store"
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
  default     = "prod"
}

# ── Base de datos ──────────────────────────────────────────────────────────────

variable "db_name" {
  description = "Nombre de la base de datos PostgreSQL"
  type        = string
  default     = "checkout_db"
}

variable "db_username" {
  description = "Usuario administrador de la DB"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Contraseña de la DB — se pasa como variable sensible, nunca en código"
  type        = string
  sensitive   = true
}

# ── Backend ────────────────────────────────────────────────────────────────────

variable "backend_image" {
  description = "URI completa de la imagen Docker del backend en ECR (se actualiza en cada deploy)"
  type        = string
  default     = ""
}

variable "backend_port" {
  description = "Puerto que expone el contenedor NestJS"
  type        = number
  default     = 3000
}
