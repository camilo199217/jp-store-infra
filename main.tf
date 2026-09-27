# ─── Provider ─────────────────────────────────────────────────────────────────
# Le decimos a Terraform que vamos a usar AWS y qué versión mínima del provider.
# El profile "personal" coincide con el que configuramos con `aws configure --profile personal`.

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # El state de Terraform (qué recursos existen) se guarda en S3.
  # Esto permite que cualquier persona del equipo (o el CI/CD) lo comparta.
  # El bucket lo creamos manualmente UNA vez antes de hacer `terraform init`.
  backend "s3" {
    bucket  = "jp-store-tfstate"
    key     = "prod/terraform.tfstate"
    region  = "us-east-1"
    profile = "personal"
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "personal"
}
