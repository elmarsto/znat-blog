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
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ca-central-1"
}

variable "repository_url" {
  description = "GitHub repository URL"
  type        = string
}

variable "github_access_token" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "Domain name"
  type        = string
}

resource "aws_iam_role" "amplify_role" {
  name = "blog-role"

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
  name = "blog-policy"
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

# 1. Create an ECR Repository (if it doesn't exist)
resource "aws_ecr_repository" "builder" {
  name                 = var.build_container
  image_tag_mutability = "MUTABLE"       # or "IMMUTABLE" - consider best practices
}

# 2. Get Authentication Data to authenticate Docker with ECR
data "aws_ecr_authorization_token" "ecr_token" {}

# 3.  Local provider to interact with Docker on your machine
provider "docker" {
  host = "unix:///var/run/docker.sock" # For Linux. May vary on other OS.
}

data "docker_registry_image" "builder_image" {
  name = "${var.build_container}:latest" # The tag you want to push
}

# 5. Tag the Docker Image with the ECR Repository URI
resource "docker_image" "builder_image" {
  name = "${aws_ecr_repository.builder.repository_url}:latest"
  image_name = "${var.build_container}:latest"
  depends_on = [
    data.docker_registry_image.builder_image
  ]
}
# 6. Push the Docker Image to ECR
resource "null_resource" "push_image" {
  triggers = {
    image_id = data.docker_registry_image.builder_image.id
  }

  provisioner "local-exec" {
    command = <<EOF
      docker login -u AWS -p "${data.aws_ecr_authorization_token.ecr_token.proxy_password}" "${data.aws_ecr_authorization_token.ecr_token.proxy_endpoint}"
      TAG="${aws_ecr_repository.builder.repository_url}:latest"
      docker build . -t $TAG
      docker push $TAG
    EOF

    environment = {
      AWS_ACCESS_KEY_ID     = data.aws_ecr_authorization_token.ecr_token.user_name
      AWS_SECRET_ACCESS_KEY = data.aws_ecr_authorization_token.ecr_token.authorization_token
    }

    on_failure = "fail" # Stop if the push fails
    depends_on = [docker_image.builder_image] # Ensure the image is tagged first
  }
}


resource "aws_amplify_app" "blog" {
  name       = "blog"
  repository = var.repository_url
  iam_service_role_arn = aws_iam_role.amplify_role.arn
  access_token = var.github_access_token
  environment_variables: {
    _CUSTOM_IMAGE: "${aws_acct}.dkr.ecr.${aws_region}.amazonaws.com/${build_container}:latest"
  }
}

resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.blog.id
  branch_name = "main"
  enable_auto_build = true
}

resource "aws_amplify_domain_association" "domain" {
  count       = 1
  app_id      = aws_amplify_app.blog.id
  domain_name = var.domain_name

  sub_domain {
    branch_name = aws_amplify_branch.main.branch_name
    prefix      = "www"
  }
}



output "repository_url" {
  value = aws_ecr_repository.example.repository_url
  description = "The URL of the ECR repository containing the build container image"
}


output "ecr_image_name" {
  value = "${aws_ecr_repository.example.repository_url}:latest"
  description = "The full build container image name in ECR."
}


output "amplify_app_id" {
  description = "Amplify App ID"
  value       = aws_amplify_app.blog.id
}

output "amplify_app_arn" {
  description = "Amplify App ARN"
  value       = aws_amplify_app.blog.arn
}

output "app_url" {
  description = "The site URL"
  value       = "https://${var.domain_name}"
}


