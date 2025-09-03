output "vpc_id"             { value = aws_vpc.byoc.id }
output "private_subnets"    { value = [for s in aws_subnet.private : s.id] }
output "public_subnets"     { value = [for s in aws_subnet.public : s.id] }
output "byoc_secret_arn"    { value = aws_secretsmanager_secret.pinecone_api.arn }
output "alb_dns_name"       { value = aws_lb.internal.dns_name }
output "ecs_cluster_name"   { value = aws_ecs_cluster.app.name }
output "ecs_service_name"   { value = aws_ecs_service.app.name }
