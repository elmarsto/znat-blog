set dotenv-load := true

[private]
list:
  just --list

# Run this once per clone of repo
setup:
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
    -sops decrypt --filename-override .env .env.enc > .env
    -sops decrypt terraform.tfstate.enc > terraform.tfstate

# Encrypt .env as .env.enc
encrypt:
    -sops encrypt .env > .env.enc && git add .env.enc
    -sops encrypt terraform.tfstate > terraform.tfstate.enc && git add terraform.tfstate.enc

# watce for changes, hot reload, show browser
serve:
    -xdg-open http://localhost:1111 &
    zola serve


# Run this when you want to redeploy with changes to AWS, remembering that most deploys don't need this & happen automatically upon `git push` to `main`
deploy:
    #!/usr/bin/env bash
    set -ex
    trap 'echo "Exit status $? at line $LINENO from: $BASH_COMMAND"' ERR
    DOMAIN=`url-parser --url $(yq '.base_url' {{justfile_directory()}}/config.toml) host`
    terraform apply -var "domain=${DOMAIN}"
    just encrypt
    TAG=$(terraform output -json | jaq -r '.ecr_container_url.value')
    aws ecr get-login-password --region ${TF_VAR_region} | docker login --username AWS --password-stdin "${TAG%%/*}"
    docker build . -t "$TAG"
    docker push "$TAG"

