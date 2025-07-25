terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.6.2"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
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

resource "aws_ecr_repository" "builder" {
  name                 = var.img
  image_tag_mutability = "MUTABLE"
}


resource "aws_ecr_repository_policy" "builder" {
  repository = aws_ecr_repository.builder.name
  policy = jsonencode({
    "Version" : "2008-10-17",
    "Statement" : [
      {
        "Sid" : "ReadOnlyPermissions",
        "Effect" : "Allow",
        "Principal" : "*",
        "Action" : [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:DescribeImageScanFindings",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:GetAuthorizationToken",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetLifecyclePolicy",
          "ecr:GetLifecyclePolicyPreview",
          "ecr:GetRepositoryPolicy",
          "ecr:ListImages",
          "ecr:ListTagsForResource"
        ]
      }
    ]
  })
}

resource "aws_amplify_app" "znat" {
  name       = "znat-app"
  repository = var.repo
  access_token = var.gh_pat
  environment_variables = {
    _CUSTOM_IMAGE : "${aws_ecr_repository.builder.repository_url}:latest"
  }
}

resource "aws_amplify_branch" "main" {
  app_id            = aws_amplify_app.znat.id
  branch_name       = "main"
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
  value       = "${aws_ecr_repository.builder.repository_url}:latest"
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
  value       = "https://www.${var.domain}/"
}

output "region" {
  description = "The AWS Region"
  value = var.region
}


