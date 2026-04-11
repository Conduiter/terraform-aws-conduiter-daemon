variable "daemon_name" {
  description = "Unique name for this daemon instance"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where the daemon will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet for the daemon instance"
  type        = string
}

variable "relay_endpoint" {
  description = "WSS endpoint of the relay this daemon connects to (leave empty for sender-only daemons)"
  type        = string
  default     = ""
}

variable "api_endpoint" {
  description = "URL of the Conduiter API"
  type        = string
  default     = "https://api.conduiter.com"
}

variable "org_token" {
  description = "Org registration token from the Conduiter dashboard"
  type        = string
  sensitive   = true
}

variable "s3_bucket" {
  description = "S3 bucket name for file storage"
  type        = string
}

variable "s3_prefix" {
  description = "S3 key prefix within the bucket (e.g. 'incoming/' or '')"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "image_tag" {
  description = "Docker image tag for the daemon container"
  type        = string
  default     = "latest"
}

variable "watch_directories" {
  description = "List of local directories the daemon watches for outbound files"
  type        = list(string)
  default     = []
}

variable "daemon_mode" {
  description = "Daemon mode: sender, receiver, or both. Receiver/both require relay_id."
  type        = string
  default     = "sender"
}

variable "relay_name" {
  description = "Name of the relay this daemon routes through (required for receiver/both modes)"
  type        = string
  default     = ""
}
