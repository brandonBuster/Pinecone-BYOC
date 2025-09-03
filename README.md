# Pinecone BYOC + Private ECS on Fargate (AWS)

A secure, private‑by‑default Terraform stack that prepares your AWS account for **Pinecone BYOC** and deploys an **always‑on ECS/Fargate service** (internal ALB) that consumes secrets via **AWS Secrets Manager** over **VPC Endpoints**, with **KMS CMK** encryption and **least‑privilege IAM**.

> ✅ Secret values never enter Terraform state. You create the secret *container* in Terraform and set its value **out‑of‑band** (CLI/CI).
>
> ✅ All control/data paths are private (Interface VPC Endpoints, optional PrivateLink for Pinecone).

---

## What gets created

- **VPC** with 2× public + 2× private subnets, IGW, 2× NAT
- **Route tables** (public + per‑AZ private)
- **Gateway VPC Endpoint (S3)** and **Interface VPC Endpoints** for: ECR (api/dkr), Logs, SSM, EC2, KMS, STS
- **(Optional) Third‑party PrivateLink endpoints** for Pinecone (supply service names)
- **Security groups** for interface endpoints, ECS service, and internal ALB
- **KMS CMK** with rotation (encrypts Secrets Manager)
- **Secrets Manager secret (shell)** for `PINECONE_API_KEY` with restrictive resource policy (only allowed principals, only via your VPC endpoint)
- **ECS cluster**
- **IAM roles**:
  - ECS **execution role** (ECR/Logs)
  - ECS **task role** with least‑privilege access to the specific secret + `kms:Decrypt`
- **CloudWatch Logs group**
- **ECS task definition** (Fargate), runtime secret injection (no plaintext in TF)
- **Internal ALB**, target group, and listener
- **ECS service** (private subnets, no public IP), with **CPU target tracking autoscaling**

---

## File Map (what creates what)

- **`network.tf`**: VPC, subnets, IGW, NATs, route tables, S3 Gateway, Interface VPC Endpoints (AWS), optional PrivateLink (Pinecone), VPCe SG
- **`kms.tf`**: Customer‑managed KMS key (rotation on) for Secrets Manager
- **`endpoints_secrets.tf`**: Interface endpoints for **Secrets Manager** and **KMS**
- **`secrets.tf`**: Secrets Manager **secret shell** + strict **resource policy**; outputs secret ARN
- **`ecs_cluster.tf`**: ECS cluster (Container Insights on)
- **`iam_ecs.tf`**: Task **execution role** & **task role**, least‑privilege policies to read the secret and decrypt with CMK
- **`logs.tf`**: CloudWatch Log Group
- **`alb_internal.tf`**: Internal ALB + TG + Listener
- **`sg_app.tf`**: ECS service security group
- **`task_definition.tf`**: Fargate task definition with secret injection at runtime
- **`service.tf`**: ECS service (private subnets, no public IP), integrated with ALB
- **`autoscaling.tf`**: Target tracking on ECS service CPU
- **`providers.tf`**, **`variables.tf`**, **`outputs.tf`**: Providers, inputs, outputs
  - Pinecone provider is optional; only used if you want to manage indexes (no secrets in state).

---

## Security posture (quick notes)

- **Secrets**: Encrypted by **KMS CMK** (rotation on); access further restricted by:
  - **Secrets Manager resource policy** → only specific **IAM principals** *and* only via your **VPC Endpoint**
  - **Task Role policy** → `secretsmanager:GetSecretValue` on that one secret + `kms:Decrypt` on the CMK
- **Networking**: All calls to AWS services go through **Interface VPC Endpoints** (no public internet). ECS service is **private** behind an **internal ALB**.
- **State safety**: No secret values in Terraform resources; values are injected **after** apply via CLI/CI.

---

## Prereqs

- Terraform ≥ **1.6**
- AWS credentials with permissions to create VPC, IAM, ECS, ALB, VPC Endpoints, KMS, Secrets Manager
- Your **container image** published to ECR (or a reachable registry)
- (Optional) Pinecone BYOC onboarding details (PrivateLink service names, account ID, external ID)

---

## Configure

Edit or pass these **variables** (see `variables.tf`):

- **Region & CIDRs**: `aws_region`, `vpc_cidr`, `private_subnet_cidrs`, `public_subnet_cidrs`
- **App**: `app_name`, `container_image`, `container_port`, `desired_count`, `task_cpu`, `task_memory`
- **Secrets access**: `app_reader_principal_arns` → include your **ECS task role ARN** (created here) *after* first apply, or pre‑seed with the expected ARN string.
- **Pinecone** (optional): `pinecone_vpce_services` (list of PrivateLink service names), `pinecone_api_key`, `pinecone_environment`

> For BYOC trust: set `pinecone_aws_account_id` and `pinecone_external_id` in `variables.tf` and include a matching **assume‑role** if Pinecone asks you to create one (some orgs do this during onboarding).

---

## Deploy (step‑by‑step)

1. **Init**
   ```bash
   terraform init
   ```

2. **Plan**
   ```bash
   terraform plan      -var="container_image=<your-account-id>.dkr.ecr.<region>.amazonaws.com/your-repo:tag"      -var="app_reader_principal_arns=[]"
   ```
   > You can initially leave `app_reader_principal_arns` empty; we’ll still create the secret. After the first apply, update it with the created **task role ARN** from outputs and re‑apply to enforce the resource policy.

3. **Apply**
   ```bash
   terraform apply      -var="container_image=<your ecr uri>"      -auto-approve
   ```

4. **Inject secret value (out‑of‑band)**
   ```bash
   PINECONE_SECRET_ARN=$(terraform output -raw byoc_secret_arn)

   aws secretsmanager put-secret-value      --secret-id "$PINECONE_SECRET_ARN"      --secret-string '{"PINECONE_API_KEY":"<redacted>"}'
   ```
   > No plaintext flows through Terraform. This writes the first version of the secret.

5. **(Optional) Lock down secret to the task role**
   - Capture `ecs_task_role` ARN from outputs or AWS console.
   - Re‑run `terraform apply` with:
     ```bash
     terraform apply -var='app_reader_principal_arns=["arn:aws:iam::<account-id>:role/byoc-agents-task-role"]'
     ```

6. **Test service health**
   - Find the **ALB DNS** from outputs: `alb_dns_name`
   - Curl inside the VPC (from a bastion/SSM session or VPC‑connected host):
     ```bash
     curl http://<alb_dns_name>/health
     ```

7. **(Optional) Pinecone PrivateLink**
   - Add Pinecone service names to `pinecone_vpce_services` and re‑apply.
   - Follow Pinecone’s DNS guidance if a private hosted zone/CNAME is required.

---

## App: consuming the secret at runtime

This task definition injects `PINECONE_API_KEY` via ECS **secrets**. Your container just reads it from the environment:

```bash
# inside the container
echo "$PINECONE_API_KEY" | wc -c
```

No application change is needed beyond reading standard env vars.

---

## Notes & tweaks

- **TLS inside VPC**: Switch ALB listener to HTTPS with an **internal ACM cert**.
- **Routing**: Add a Route 53 **private hosted zone** (e.g., `api.internal.yourcorp`) pointing to the ALB.
- **Observability**: Adjust log retention, add metrics/alarms for CPU, 5xx, and target health.
- **Cost controls**: Downsize NATs to 1 AZ, use smaller task sizes, or switch to NLB if L7 isn’t needed.

---

## Cleanup

```bash
terraform destroy
```

> This will remove infrastructure but **not** force‑delete your secret versions. Rotate or delete secrets manually if needed.
