resource "aws_ecs_cluster" "app" {
  name = "byoc-agents-cluster"
  setting { name = "containerInsights", value = "enabled" }
  tags = { Name = "byoc-ecs-cluster" }
}
