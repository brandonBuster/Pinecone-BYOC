# Restrictive resource policy: only specific principals AND only via our VPC endpoint
data "aws_iam_policy_document" "secret_policy" {
  statement {
    sid     = "AllowReadToAppPrincipalsViaVpcEndpoint"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue","secretsmanager:DescribeSecret"]
    principals {
      type        = "AWS"
      identifiers = var.app_reader_principal_arns
    }
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpce"
      values   = [aws_vpc_endpoint.secretsmanager.id]
    }
  }
  statement {
    sid     = "DenyFromOutsideVpcEndpoint"
    effect  = "Deny"
    actions = ["secretsmanager:GetSecretValue"]
    principals { type = "*", identifiers = ["*"] }
    resources = ["*"]
    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceVpce"
      values   = [aws_vpc_endpoint.secretsmanager.id]
    }
  }
}

resource "aws_secretsmanager_secret" "pinecone_api" {
  name        = "byoc/pinecone/api"
  kms_key_id  = aws_kms_key.secrets.arn
  policy      = data.aws_iam_policy_document.secret_policy.json
  tags        = { Name = "pinecone-api-key" }
}

output "pinecone_secret_arn" {
  value = aws_secretsmanager_secret.pinecone_api.arn
}
