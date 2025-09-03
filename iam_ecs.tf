# Execution role (pull image, write logs)
data "aws_iam_policy_document" "ecs_task_exec_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service", identifiers = ["ecs-tasks.amazonaws.com"] }
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.app_name}-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_exec_trust.json
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Application task role (read secret + decrypt with CMK)
resource "aws_iam_role" "ecs_task_role" {
  name               = "${var.app_name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_exec_trust.json
}

data "aws_iam_policy_document" "read_secret_doc" {
  statement {
    sid       = "AllowReadSpecificSecretViaVpcEndpoint"
    actions   = ["secretsmanager:GetSecretValue","secretsmanager:DescribeSecret"]
    resources = [aws_secretsmanager_secret.pinecone_api.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpce"
      values   = [aws_vpc_endpoint.secretsmanager.id]
    }
  }
  statement {
    sid       = "AllowKmsDecryptForSecrets"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.secrets.arn]
  }
}

resource "aws_iam_policy" "read_secret" {
  name   = "${var.app_name}-read-pinecone-secret"
  policy = data.aws_iam_policy_document.read_secret_doc.json
}

resource "aws_iam_role_policy_attachment" "attach_read_secret" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.read_secret.arn
}
