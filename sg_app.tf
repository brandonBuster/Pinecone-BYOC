# Security group for ECS service tasks
resource "aws_security_group" "app" {
  name        = "${var.app_name}-sg"
  description = "App tasks SG"
  vpc_id      = aws_vpc.byoc.id

  # Ingress only from internal ALB
  ingress {
    description     = "From ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Egress scoped to VPC (tighten as needed)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.byoc.cidr_block]
  }

  tags = { Name = "${var.app_name}-sg" }
}
