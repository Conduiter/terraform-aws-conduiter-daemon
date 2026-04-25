# Conduiter Daemon - AWS Terraform Module

The Conduiter Daemon runs inside your network, polls for transfer requests, encrypts and decrypts files using end-to-end encryption, and reads from and writes to S3. It connects outbound to a Conduiter Relay to exchange data with other organizations' daemons.

## Usage

```hcl
module "daemon" {
  source  = "conduiter/conduiter-daemon/aws"
  version = "~> 1.0"

  daemon_name    = "production"
  org_token      = var.org_token
  vpc_id         = var.vpc_id
  subnet_id      = var.subnet_id
  relay_endpoint = module.relay.relay_endpoint
  s3_bucket      = var.s3_bucket
  api_endpoint   = "https://api.conduiter.com"
}
```

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.5 |
| AWS provider | ~> 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| daemon_name | Unique name for this daemon instance | `string` | n/a | yes |
| vpc_id | ID of the VPC where the daemon will be deployed | `string` | n/a | yes |
| subnet_id | ID of the subnet for the daemon instance | `string` | n/a | yes |
| relay_endpoint | HTTPS endpoint of the relay this daemon connects to | `string` | n/a | yes |
| api_endpoint | URL of the Conduiter API | `string` | `"https://api.conduiter.com"` | no |
| org_token | Org registration token from the Conduiter dashboard | `string` | n/a | yes |
| s3_bucket | S3 bucket name for file storage | `string` | n/a | yes |
| s3_prefix | S3 key prefix within the bucket (e.g. 'incoming/' or '') | `string` | `""` | no |
| instance_type | EC2 instance type | `string` | `"t3.micro"` | no |
| image_tag | Docker image tag for the daemon container | `string` | `"latest"` | no |
| watch_directories | List of local directories the daemon watches for outbound files | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_id | EC2 instance ID of the daemon |
| private_ip | Private IP address of the daemon EC2 instance |
| security_group_id | ID of the daemon security group |
| iam_role_arn | ARN of the daemon IAM role |
| secret_arn | ARN of the Secrets Manager secret storing the daemon keypair |

See the [full documentation](https://app.conduiter.com/docs/getting-started/aws-setup) for detailed setup instructions.
