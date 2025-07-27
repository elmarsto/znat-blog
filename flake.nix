{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs";
  };
  outputs = {
    flake-utils,
    nixpkgs,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg: true;
        };
        buildPackages = with pkgs; [
          zola
          git-cliff
        ];
      in {
        devShells = {
          ci = pkgs.mkShell {
            name = "znat-ci";
            packages = buildPackages;
          };
          default = pkgs.mkShell {
            name = "znat";
            shellHook = ''
              set -a; source .env; set +a
              eval "$(direnv hook bash)"
            '';
            packages = with pkgs;
              [
                age
                alejandra
                awscli2
                commitlint-rs
                cz-cli
                docker
                git
                git-secrets
                git-cliff
                gh
                jaq
                jujutsu
                lefthook
                mdl
                moreutils
                sops
                terraform
                tflint
                toml-sort
                url-parser
                yamllint
                yq-go
                zola
              ]
              ++ buildPackages;
          };
        };
      }
    );
}
