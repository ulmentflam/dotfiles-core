{
  description = "One machine's Home Manager configuration: dotfiles-core plus what is mine";

  inputs.dotfiles-core.url = "github:ulmentflam/dotfiles-core";

  outputs =
    { self, dotfiles-core, ... }:
    let
      system = "aarch64-darwin";
      name = "work";
    in
    {
      homeConfigurations.${name} = dotfiles-core.lib.mkHome {
        inherit system;
        modules = [ ./home.nix ];
      };

      # nix run .#build | .#build-switch | .#rollback
      apps.${system} = dotfiles-core.lib.mkHomeApps {
        flake = self;
        inherit system name;
      };

      formatter.${system} = dotfiles-core.inputs.nixpkgs.legacyPackages.${system}.nixfmt;
    };
}
