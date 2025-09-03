data "aws_caller_identity" "current" {}

resource "aws_kms_key" "secrets" {
  description         = "CMK for encrypting BYOC app secrets"
  enable_key_rotation = true
  policy = jsonencode({
    Version = "2012-10-17",
    Statement: [
      {
        Sid: "AllowAccountAdmins",
        Effect: "Allow",
        Principal: { AWS: "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" },
        Action: "kms:*",
        Resource: "*"
      },
      {
        Sid: "AllowSecretsManagerUseOfKey",
        Effect: "Allow",
        Principal: { Service: "secretsmanager.amazonaws.com" },
        Action: ["kms:Encrypt","kms:Decrypt","kms:ReEncrypt*","kms:GenerateDataKey*","kms:DescribeKey"],
        Resource: "*"
      }
    ]
  })
  tags = { Name = "byoc-secrets-kms" }
}
