# ─── VPC y red ────────────────────────────────────────────────────────────────
# La VPC es la red privada virtual donde viven todos los recursos de AWS.
# Creamos subnets públicas (para el ALB) y privadas (para ECS y RDS).

# Obtenemos las zonas de disponibilidad de la región automáticamente
data "aws_availability_zones" "available" {
  state = "available"
}

# ── VPC principal ──────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project}-vpc"
    Environment = var.environment
  }
}

# ── Subnets públicas (ALB vive aquí — recibe tráfico de internet) ─────────────
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project}-public-${count.index + 1}"
    Environment = var.environment
  }
}

# ── Subnets privadas (ECS y RDS viven aquí — sin acceso directo desde internet) ──
resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${var.project}-private-${count.index + 1}"
    Environment = var.environment
  }
}

# ── Internet Gateway (permite que la VPC se conecte a internet) ───────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project}-igw"
    Environment = var.environment
  }
}

# ── Tabla de rutas pública (el tráfico de las subnets públicas sale por el IGW) ──
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project}-rt-public"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
