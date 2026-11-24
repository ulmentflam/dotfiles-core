{
  description = "dotfiles-core: a portable Home Manager configuration for macOS and Linux (zsh, git, editors, CLI tools, AI-agent tooling)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Third-party agent skills, registered in modules/skills/sources.nix and
    # installed only at a revision modules/skills/reviews.json approves.
    # Update them with `nix run .#skills-review -- --update`.
    modular-skills = {
      url = "github:modular/skills";
      flake = false;
    };
    superpowers = {
      url = "github:obra/superpowers";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-index-database,
      ...
    }@inputs:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      coreLib = import ./lib { inherit self inputs; };

      # Each module stands alone (it imports options.nix itself), so a
      # nix-darwin or NixOS consumer can take only the ones it wants.
      modules = {
        options = ./modules/options.nix;
        programs = ./modules/programs.nix;
        files = ./modules/files.nix;
        packages = ./modules/packages.nix;
        ai-options = ./modules/ai-options.nix;
        ai-files = ./modules/ai-files.nix;
        ai-local-docs = ./modules/ai-local-docs.nix;
        claude-code = ./modules/claude-code.nix;
        codex = ./modules/codex.nix;
        antigravity-cli = ./modules/antigravity-cli.nix;
        local-bin-path = ./modules/local-bin-path.nix;
        github-token = ./modules/github-token.nix;
        git-hooks = ./modules/git-hooks.nix;
        skills-settings = ./modules/skills/settings.nix;
        opencode = ./modules/opencode.nix;
        darwin-apps = ./modules/darwin-apps.nix;
      };
    in
    {
      lib = coreLib;

      homeModules = modules // {
        standalone = ./modules/standalone.nix;
        default =
          { lib, ... }:
          {
            imports = [ nix-index-database.homeModules.nix-index ] ++ builtins.attrValues modules;
            dotfiles.ai.skills = lib.mkDefault coreLib.skills;
          };
      };

      # Placeholder identity, for evaluation and as a starting point. A real
      # machine uses its own flake (`nix flake init -t <this flake>#overlay`).
      homeConfigurations = forAllSystems (
        system:
        coreLib.mkHome {
          inherit system;
          modules = [ ./examples/home.nix ];
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        coreLib.mkHomeApps {
          flake = self;
          inherit system;
          name = system;
        }
        // {
          skills-review = {
            type = "app";
            program = "${pkgs.writeShellScript "skills-review" ''
              PATH=${pkgs.git}/bin:$PATH
              exec ${pkgs.bash}/bin/bash ${./apps/skills-review} "$@"
            ''}";
          };
        }
      );

      templates.overlay = {
        path = ./templates/overlay;
        description = "A machine's own flake: dotfiles-core plus identity, apps and anything private";
      };

      # `nix fmt`: nixfmt, the RFC 166 formatter. statix and deadnix stay out of
      # it because they change semantics, not layout; run them from `nix develop`.
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            nativeBuildInputs = with pkgs; [
              bashInteractive
              git
              jq
              nixfmt
              statix
              deadnix
              gitleaks
            ];
          };
        }
      );
    };
}
