# Everything that makes this machine yours. dotfiles-core supplies the shell,
# git, editors, CLI tools and AI tooling; set the identity below and add what
# belongs to this machine only. Keep secrets out of this file: it lands in the
# world-readable Nix store.
{ pkgs, ... }:

let
  # Your macOS short name (`id -un`) and where this flake is checked out.
  username = "CHANGE-ME";
  checkout = "dotfiles-work";
in
{
  home = {
    inherit username;
    # The Home Manager release this machine started on. Set it once; never
    # bump it to "upgrade" (see `man home-configuration.nix`).
    stateVersion = "25.05";
  };

  dotfiles = {
    user = {
      name = "CHANGE-ME";
      email = "CHANGE-ME@example.com";
    };

    repo = {
      path = "~/${checkout}";
      gitConfigFile = "~/${checkout}/home.nix";
    };

    # mise pins, kept in this checkout so `mise upgrade --bump` writes back.
    toolVersions = "/Users/${username}/${checkout}/.tool-versions";
    ai.docs.toolVersionsFile = ./.tool-versions;

    # SSH commit signing. With 1Password holding the key:
    #   git.signing = {
    #     key = "ssh-ed25519 AAAA...";
    #     signer = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
    #   };
    #   ssh.identityAgent = "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
    # Or a key on disk, signed by ssh-keygen: set only `git.signing.key`.

    # Hosts kept out of this repository can live in ~/.ssh/config_external.
    ssh.includes = [ "~/.ssh/config_external" ];

    # Touch ID for sudo: run `nix run .#touchid-sudo` once (it writes
    # /etc/pam.d/sudo_local, outside Home Manager's reach).

    # GUI apps: casks through `brew bundle` (see modules/darwin-apps.nix in
    # dotfiles-core for when to use `darwin.apps` from nixpkgs instead).
    darwin.brewfile = {
      enable = true;
      casks = [
        "1password"
        "1password-cli"
        "claude"
        "cursor"
        "ghostty"
        "google-chrome"
        # Paste, Bartender and CleanShot X stand-ins. Maccy gets Paste's
        # Command-Shift-V and paste-on-select; Thaw needs Accessibility and
        # Screen Recording; MacShot Offline takes Command-Shift-3 and -4 from
        # macOS and needs Screen Recording.
        "maccy"
        "thaw"
        "macshot-offline"
        "raycast"
        "slack"
        "visual-studio-code"
        "zoom"
      ];
    };
    # Docker without Docker Desktop's license: `colima start`, then the docker CLI.
    darwin.apps = [ ];

    # Core CLI packages this machine does without (names as `nix search` shows).
    # mise is not in this list's reach: programs.mise always installs it.
    packages.exclude = [
      "tor"
      "brev-cli"
      # YubiKey / FIDO tooling
      "age-plugin-yubikey"
      "libfido2"
    ];
  };

  home.packages = with pkgs; [
    colima
    docker-client
  ];
}
