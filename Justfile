set dotenv-load := true

[private]
list:
  just --list

# Run this once per clone of repo
setup:
    #!/usr/bin/env bash
    git submodule update --init --recursive
    just decrypt
    lefthook install
    tflint --init
    terraform init
    @echo "edit your .env file and when it looks correct, run `just deploy`"

# Enter the development shell
shell:
    nix develop

# Decrypt .env.enc as .env
decrypt:
    sops decrypt --filename-override .env .env.enc > .env
    sops decrypt terraform.tfstate.enc > terraform.tfstate

# Encrypt .env as .env.enc
encrypt:
    sops encrypt .env > .env.enc
    sops encrypt terraform.tfstate > terraform.tfstate.enc

# watce for changes, hot reload, show browser
serve:
    xdg-open https://localhost:1111 &
    zola serve

# Run this when you want to redeploy with changes to AWS, remembering that most deploys don't need this & happen automatically upon `git push` to `main`
deploy:
    #!/usr/bin/env bash
    set -x
    terraform apply
    ID=$(terraform output -json | jaq -r '.amplify_app_id.value')
    TAG=$(terraform output -json | jaq -r '.ecr_container_url.value')
    REGION=$(terraform output -json | jaq -r '.region.value')
    ECR_ROOT="${TAG%%/*}"
    aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_ROOT
    docker build . -t "$TAG"
    docker push "$TAG"



