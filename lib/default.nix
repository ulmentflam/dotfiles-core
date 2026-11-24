# Everything a consumer flake calls. `self` and `inputs` are this flake's.
{ self, inputs }:

let
  inherit (inputs) nixpkgs home-manager;
in
rec {
  # { <name> = <directory>; } of local plus reviewed third-party skills. A
  # consumer adds its own skill directories:
  #   dotfiles-core.lib.mkSkills { locals = [ (dotfiles-core + "/skills") ./skills ]; }
  mkSkills = args: import ./skills.nix ({ inherit inputs; } // args);

  # This flake's own skill set.
  skills = mkSkills { };

  shellAliases = import ./shell-aliases.nix;
  packages = import ./packages.nix;
  aiFiles = import ./ai-files.nix;
  programs = import ./programs.nix;

  # Path values, not strings: Home Manager then copies only these directories
  # into the store, content-addressed, rather than referencing the whole
  # source tree as `dotfiles-core + "/skills"` would.
  skillsDir = ../skills;
  agentsDir = ../agents;
  configDir = ../config;

  # A standalone Home Manager configuration with every core module. `modules`
  # supplies the identity (home.username, dotfiles.user.*), home.stateVersion
  # and anything machine-specific.
  mkHome =
    {
      system,
      modules,
      nixpkgsConfig ? {
        allowUnfree = true;
      },
      extraSpecialArgs ? { },
    }:
    home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        inherit system;
        config = nixpkgsConfig;
      };
      inherit extraSpecialArgs;
      modules = [
        self.homeModules.default
        self.homeModules.standalone
      ]
      ++ modules;
    };

  # `nix run .#build` and `nix run .#build-switch` for the flake `flake`
  # (usually the consumer's `self`) and its homeConfigurations.<name>.
  mkHomeApps =
    {
      flake,
      system,
      name,
    }:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      hm = home-manager.packages.${system}.home-manager;
      app = scriptName: text: {
        type = "app";
        program = "${pkgs.writeShellScript scriptName text}";
      };
      attr = ''${flake}#homeConfigurations."${name}".activationPackage'';
    in
    {
      build = app "build" ''
        set -euo pipefail
        echo "Building homeConfigurations.${name} (not activated)..."
        nix build --no-link --print-out-paths '${attr}' "$@"
      '';
      build-switch = app "build-switch" ''
        set -euo pipefail
        # Files Home Manager would overwrite are kept as <name>.backup.
        exec ${hm}/bin/home-manager switch -b backup --flake '${flake}#${name}' "$@"
      '';
      rollback = app "rollback" ''
        set -euo pipefail
        ${hm}/bin/home-manager generations
        echo
        echo "To roll back, run the chosen generation's activate script:"
        echo "  /nix/store/<hash>-home-manager-generation/activate"
      '';
    };
}
