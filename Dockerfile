# This Dockerfile is used by AWS Amplify to build the site. use `just push-`

FROM amazonlinux:latest


# Install shadow-utils to get groupadd command
RUN yum update -y && yum install -y shadow-utils git

RUN curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install linux --no-confirm --init none


ENV PATH="/nix/var/nix/profiles/default/bin:${PATH}"

WORKDIR /app

COPY flake.nix flake.nix
COPY flake.lock flake.lock
COPY .env .env

RUN nix develop .#ci --command true

CMD ["/bin/bash"]
