terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "daemon" {
  name              = "/conduiter/daemon/${var.daemon_name}"
  retention_in_days = 30

  tags = {
    Name        = "conduiter-daemon-${var.daemon_name}"
    Environment = var.daemon_name
    Service     = "daemon"
  }
}

# -----------------------------------------------------------------------------
# Secrets Manager - Daemon Keypair
# -----------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "daemon_keypair" {
  name                    = "conduiter/daemon/${var.daemon_name}/keypair"
  description             = "Conduiter daemon keypair for ${var.daemon_name}"
  recovery_window_in_days = 7

  tags = {
    Name        = "conduiter-daemon-${var.daemon_name}-keypair"
    Environment = var.daemon_name
    Service     = "daemon"
  }
}

resource "aws_secretsmanager_secret_version" "daemon_keypair" {
  secret_id     = aws_secretsmanager_secret.daemon_keypair.id
  secret_string = jsonencode({})

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# -----------------------------------------------------------------------------
# IAM - Instance Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "daemon" {
  name = "conduiter-daemon-${var.daemon_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "conduiter-daemon-${var.daemon_name}"
    Environment = var.daemon_name
    Service     = "daemon"
  }
}

resource "aws_iam_role_policy_attachment" "daemon_ssm" {
  role       = aws_iam_role.daemon.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "daemon_s3" {
  name = "s3-read-write"
  role = aws_iam_role.daemon.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadFilesToSend"
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket}/${var.s3_prefix}*"
        ]
      },
      {
        Sid    = "WriteReceivedFiles"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectTagging",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket}/${var.s3_prefix}*"
        ]
      },
      {
        Sid    = "ListBucketPrefix"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket}"
        ]
        Condition = {
          StringLike = {
            "s3:prefix" = ["${var.s3_prefix}*"]
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "daemon_secrets" {
  name = "secrets-access"
  role = aws_iam_role.daemon.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.daemon_keypair.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "daemon_logs" {
  name = "cloudwatch-logs"
  role = aws_iam_role.daemon.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.daemon.arn}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "daemon" {
  name = "conduiter-daemon-${var.daemon_name}"
  role = aws_iam_role.daemon.name

  tags = {
    Name        = "conduiter-daemon-${var.daemon_name}"
    Environment = var.daemon_name
    Service     = "daemon"
  }
}

# -----------------------------------------------------------------------------
# Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "daemon" {
  name        = "conduiter-daemon-${var.daemon_name}"
  description = "Security group for Conduiter daemon - outbound only"
  vpc_id      = var.vpc_id

  egress {
    description = "HTTPS outbound to relay and API"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "conduiter-daemon-${var.daemon_name}"
    Environment = var.daemon_name
    Service     = "daemon"
  }
}

# -----------------------------------------------------------------------------
# EC2 Instance
# -----------------------------------------------------------------------------

resource "aws_instance" "daemon" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  iam_instance_profile        = aws_iam_instance_profile.daemon.name
  vpc_security_group_ids      = [aws_security_group.daemon.id]
  associate_public_ip_address = true

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    aws_region          = data.aws_region.current.name
    daemon_name         = var.daemon_name
    relay_endpoint      = var.relay_endpoint
    api_endpoint        = var.api_endpoint
    org_token           = var.org_token
    secret_arn          = aws_secretsmanager_secret.daemon_keypair.arn
    s3_bucket           = var.s3_bucket
    image_tag           = var.image_tag
    log_group           = aws_cloudwatch_log_group.daemon.name
    watch_directories   = join(",", var.watch_directories)
  }))

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = {
    Name        = "conduiter-daemon-${var.daemon_name}"
    Environment = var.daemon_name
    Service     = "daemon"
  }
}
