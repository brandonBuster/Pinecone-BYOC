# Private interface endpoints to reach Secrets Manager & KMS without public internet
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.byoc.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.private : s.id]
  security_group_ids  = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true
  tags = { Name = "byoc-vpce-secretsmanager" }
}

resource "aws_vpc_endpoint" "kms" {
  vpc_id              = aws_vpc.byoc.id
  service_name        = "com.amazonaws.${var.aws_region}.kms"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.private : s.id]
  security_group_ids  = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true
  tags = { Name = "byoc-vpce-kms" }
}
