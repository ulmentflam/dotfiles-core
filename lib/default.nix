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
  # MacShot Offline's shortcuts, CleanShot X's names and folder, as shell
  # lines: macshot.preferences { homeDirectory = ...; }.
  macshot = import ./macshot.nix { inherit (nixpkgs) lib; };

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
    }
    // nixpkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
      # macOS: Touch ID for sudo, through /etc/pam.d/sudo_local (which macOS
      # keeps across updates). pam_reattach makes it work inside tmux. The
      # module's store path is pinned with a GC root so a garbage collection
      # cannot pull it out from under sudo.
      touchid-sudo = app "touchid-sudo" ''
        set -euo pipefail
        [ "$(uname)" = Darwin ] || { echo "touchid-sudo: macOS only" >&2; exit 1; }
        want='# Managed by dotfiles-core (nix run .#touchid-sudo). Survives macOS updates.
        auth       optional       ${pkgs.pam-reattach}/lib/pam/pam_reattach.so
        auth       sufficient     pam_tid.so'
        if [ "$(cat /etc/pam.d/sudo_local 2>/dev/null)" = "$want" ]; then
          echo "Touch ID for sudo is already on."
          exit 0
        fi
        # Touch ID already on through something else (nix-darwin, by hand):
        # leave it alone.
        if /usr/bin/grep -qs '^auth[[:space:]].*pam_tid\.so' /etc/pam.d/sudo_local; then
          echo "Touch ID for sudo is already on (/etc/pam.d/sudo_local is managed elsewhere; left as is)."
          exit 0
        fi
        # --check: report and change nothing (exit 1 when it would write).
        if [ "''${1:-}" = --check ]; then
          echo "Touch ID for sudo is off; run without --check to turn it on."
          exit 1
        fi
        if [ -s /etc/pam.d/sudo_local ]; then
          echo "Replacing /etc/pam.d/sudo_local, which currently reads:"
          sed 's/^/  /' /etc/pam.d/sudo_local
        fi
        echo "Writing /etc/pam.d/sudo_local (sudo asks for your password this once)..."
        printf '%s\n' "$want" | /usr/bin/sudo /usr/bin/tee /etc/pam.d/sudo_local >/dev/null
        /usr/bin/sudo /bin/chmod 444 /etc/pam.d/sudo_local
        /usr/bin/sudo /bin/ln -sfn ${pkgs.pam-reattach} /nix/var/nix/gcroots/dotfiles-core-pam-reattach
        echo "Done. Open a new terminal and run: sudo -v"
      '';
    };
}
