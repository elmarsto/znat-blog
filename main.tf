terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "img" {
  description = "Docker image name"
  type        = string
}

variable "repo" {
  description = "GitHub repository URL"
  type        = string
}

variable "gh_pat" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
}

variable "domain" {
  description = "Domain name"
  type        = string
}

resource "aws_iam_role" "amplify_role" {
  name = "znat-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "amplify.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "amplify_policy" {
  name = "znat-policy"
  role = aws_iam_role.amplify_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_ecr_repository" "builder" {
  name                 = var.img
  image_tag_mutability = "MUTABLE"
}

data "aws_ecr_authorization_token" "ecr_token" {}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

data "docker_registry_image" "builder" {
  name = "${var.img}:latest"
}

resource "docker_image" "builder" {
  name = "${aws_ecr_repository.builder.repository_url}:latest"
  image_name = "${var.img}:latest"
  depends_on = [
    data.docker_registry_image.builder
  ]
}

resource "null_resource" "builder" {
  triggers = {
    image_id = data.docker_registry_image.builder.id
  }

  provisioner "local-exec" {
    command = <<EOF
      docker login -u AWS -p "${data.aws_ecr_authorization_token.ecr_token.proxy_password}" "${data.aws_ecr_authorization_token.ecr_token.proxy_endpoint}"
      docker push "${aws_ecr_repository.builder.repository_url}:latest"
    EOF

    environment = {
      AWS_ACCESS_KEY_ID     = data.aws_ecr_authorization_token.ecr_token.user_name
      AWS_SECRET_ACCESS_KEY = data.aws_ecr_authorization_token.ecr_token.authorization_token
    }

    on_failure = "fail"
    depends_on = [docker_image.builder]
  }
}

resource "aws_amplify_app" "znat" {
  name       = "znat-app"
  repository = var.repo
  iam_service_role_arn = aws_iam_role.amplify_role.arn
  access_token = var.gh_pat
  environment_variables = {
    _CUSTOM_IMAGE: "${aws_ecr_repository.builder.respository_url}:latest"
  }
}

resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.znat.id
  branch_name = "main"
  enable_auto_build = true
}

resource "aws_amplify_domain_association" "domain" {
  count       = 1
  app_id      = aws_amplify_app.znat.id
  domain_name = var.domain

  sub_domain {
    branch_name = aws_amplify_branch.main.branch_name
    prefix      = "www"
  }
}

output "ecr_container_url" {
  value = "${aws_ecr_repository.builder.repository_url}:latest"
  description = "The URL of the ECR repository containing the build container image"
}

output "amplify_app_id" {
  description = "Amplify App ID"
  value       = aws_amplify_app.znat.id
}

output "amplify_app_arn" {
  description = "Amplify App ARN"
  value       = aws_amplify_app.znat.arn
}

output "app_url" {
  description = "The site URL"
  value       = "https://${var.domain}"
}


