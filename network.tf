data "aws_availability_zones" "available" {}

resource "aws_vpc" "byoc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "byoc-pinecone-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.byoc.id
  tags   = { Name = "byoc-igw" }
}

# Public subnets (for NAT egress only)
resource "aws_subnet" "public" {
  for_each = {
    a = var.public_subnet_cidrs[0]
    b = var.public_subnet_cidrs[1]
  }
  vpc_id                  = aws_vpc.byoc.id
  cidr_block              = each.value
  availability_zone       = data.aws_availability_zones.available.names[tonumber(keys(aws_subnet.public)[0] == each.key ? 0 : 1)]
  map_public_ip_on_launch = true
  tags = { Name = "byoc-public-${each.key}" }
}

# Private subnets (where Pinecone data plane & ECS tasks run)
resource "aws_subnet" "private" {
  for_each = {
    a = var.private_subnet_cidrs[0]
    b = var.private_subnet_cidrs[1]
  }
  vpc_id            = aws_vpc.byoc.id
  cidr_block        = each.value
  availability_zone = data.aws_availability_zones.available.names[tonumber(keys(aws_subnet.private)[0] == each.key ? 0 : 1)]
  tags = { Name = "byoc-private-${each.key}" }
}

# NAT per AZ
resource "aws_eip" "nat" {
  for_each = aws_subnet.public
  domain   = "vpc"
  tags     = { Name = "byoc-nat-eip-${each.key}" }
}

resource "aws_nat_gateway" "nat" {
  for_each      = aws_subnet.public
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id
  tags          = { Name = "byoc-nat-${each.key}" }
  depends_on    = [aws_internet_gateway.igw]
}

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.byoc.id
  tags   = { Name = "byoc-rtb-public" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Private route tables (AZ‑aware)
resource "aws_route_table" "private" {
  for_each = aws_nat_gateway.nat
  vpc_id   = aws_vpc.byoc.id
  tags     = { Name = "byoc-rtb-private-${each.key}" }
}

resource "aws_route" "private_default" {
  for_each               = aws_route_table.private
  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[each.key].id
}

resource "aws_route_table_association" "private_assoc" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# S3 Gateway endpoint (cheap, fast access to S3)
resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id            = aws_vpc.byoc.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(
    [aws_route_table.public.id],
    [for _, rt in aws_route_table.private : rt.id]
  )
  tags = { Name = "byoc-s3-gateway" }
}

# Security group for Interface endpoints (HTTPS)
resource "aws_security_group" "vpce_sg" {
  name        = "byoc-vpce-sg"
  description = "Allow HTTPS to interface endpoints"
  vpc_id      = aws_vpc.byoc.id

  ingress {
    description = "VPC internal HTTPS to endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.byoc.cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.byoc.cidr_block]
  }
  tags = { Name = "byoc-vpce-sg" }
}

# Common Interface endpoints for private egress to AWS services
resource "aws_vpc_endpoint" "interface_aws" {
  for_each            = toset(var.interface_endpoint_services)
  vpc_id              = aws_vpc.byoc.id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.private : s.id]
  security_group_ids  = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true
  tags                = { Name = "byoc-endpoint-${replace(each.value, "com.amazonaws.${var.aws_region}.", "")}" }
}

# Optional: third‑party PrivateLink endpoints (e.g., Pinecone)
resource "aws_vpc_endpoint" "pinecone_pl" {
  for_each            = toset(var.pinecone_vpce_services)
  vpc_id              = aws_vpc.byoc.id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.private : s.id]
  security_group_ids  = [aws_security_group.vpce_sg.id]
  private_dns_enabled = false
  tags                = { Name = "byoc-pinecone-pl" }
}
