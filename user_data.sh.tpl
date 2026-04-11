#!/bin/bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Conduiter Daemon - Cloud-Init User Data
# Installs Docker and runs the conduiter-daemon container as a systemd service.
# -----------------------------------------------------------------------------

exec > >(tee /var/log/conduiter-daemon-init.log) 2>&1
echo "Starting Conduiter daemon setup at $(date)"

# Install Docker
dnf update -y
dnf install -y docker aws-cli
systemctl enable docker
systemctl start docker

# Wait for Docker to be ready
until docker info > /dev/null 2>&1; do
  echo "Waiting for Docker to start..."
  sleep 2
done

# Pull the daemon image
docker pull public.ecr.aws/y8p4n9c1/daemon:${image_tag}

# Create data directory
mkdir -p /data

# Create systemd unit file for conduiter-daemon
cat > /etc/systemd/system/conduiter-daemon.service << 'UNIT'
[Unit]
Description=Conduiter Daemon
After=docker.service
Requires=docker.service

[Service]
Type=simple
Restart=always
RestartSec=10
TimeoutStartSec=300
ExecStartPre=-/usr/bin/docker stop conduiter-daemon
ExecStartPre=-/usr/bin/docker rm conduiter-daemon
ExecStart=/usr/bin/docker run \
  --name conduiter-daemon \
  --log-driver=awslogs \
  --log-opt awslogs-region=${aws_region} \
  --log-opt awslogs-group=${log_group} \
  --log-opt awslogs-stream=daemon \
  -e CONDUITER_API_URL=${api_endpoint} \
  -e ORG_TOKEN=${org_token} \
  -e DAEMON_NAME=${daemon_name} \
  -e DAEMON_MODE=${daemon_mode} \
  -e RELAY_NAME=${relay_name} \
  -e RELAY_ENDPOINT=${relay_endpoint} \
  -e PRIVATE_KEY_ARN=${secret_arn} \
  -e CONDUITER_S3_BUCKET=${s3_bucket} \
  -e STORE_PATH=/data \
  -e AWS_REGION=${aws_region} \
  -v /data:/data \
  public.ecr.aws/y8p4n9c1/daemon:${image_tag}
ExecStop=/usr/bin/docker stop conduiter-daemon

[Install]
WantedBy=multi-user.target
UNIT

# Enable and start the service
systemctl daemon-reload
systemctl enable conduiter-daemon
systemctl start conduiter-daemon

echo "Conduiter daemon setup complete at $(date)"
