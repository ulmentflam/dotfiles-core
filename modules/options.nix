# Every value that differs between people or machines. The other modules read
# these; none of them hardcodes an identity, a path into someone's checkout, or
# a host list. Identity options have no default, so a configuration that forgets
# one fails evaluation instead of committing as somebody else.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkOption types;
  cfg = config.dotfiles;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
in
{
  options.dotfiles = {
    user = {
      name = mkOption {
        type = types.str;
        description = "Git author name.";
      };
      email = mkOption {
        type = types.str;
        description = "Git author email.";
      };
    };

    repo = {
      path = mkOption {
        type = types.str;
        example = "~/dotfiles";
        description = ''
          The checkout holding this configuration, as a shell path. Used by the
          navigation aliases and the rebuild functions.
        '';
      };
      flakeDir = mkOption {
        type = types.str;
        default = cfg.repo.path;
        defaultText = lib.literalExpression "config.dotfiles.repo.path";
        description = "Directory holding the flake.nix that builds this configuration.";
      };
      churnyInputs = mkOption {
        type = types.listOf types.str;
        default = [ "nix-index-database" ];
        description = ''
          Flake inputs that move often enough to bump without touching nixpkgs or
          home-manager. `nfu` and `nbu` update only these.
        '';
      };
      gitConfigFile = mkOption {
        type = types.str;
        default = cfg.repo.flakeDir;
        defaultText = lib.literalExpression "config.dotfiles.repo.flakeDir";
        description = "What the `gitconfig` alias opens in $EDITOR.";
      };
    };

    editor = {
      init = mkOption {
        type = types.lines;
        default = ''
          # nvim is the default editor
          export EDITOR="nvim"
          export VISUAL="nvim"
        '';
        description = "zsh lines that set EDITOR and VISUAL (and any PATH the editor needs).";
      };
      git = mkOption {
        type = types.str;
        default = "nvim";
        description = "git's core.editor. Must block until the file is closed.";
      };
    };

    git.signing = {
      key = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Public SSH key commits are signed with. null disables signing.";
      };
      signer = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
        description = "gpg.ssh.program. null keeps git's default, ssh-keygen.";
      };
    };

    ssh = {
      identityAgent = mkOption {
        # ssh_config has no escape for a double quote inside a quoted value.
        type = types.nullOr (types.strMatching ''[^"]*'');
        default = null;
        example = "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
        description = "IdentityAgent for every host (the `*` block), unquoted; it is quoted when written, so spaces are fine. null leaves ssh-agent alone.";
      };
      includes = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Files ssh_config includes, for hosts kept out of this configuration.";
      };
      hosts = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Host blocks, in programs.ssh.settings form (PascalCase OpenSSH keys).";
      };
      publicKeys = mkOption {
        type = types.attrsOf types.str;
        default = { };
        example = {
          id_github = "ssh-ed25519 AAAA...";
        };
        description = ''
          Public keys written to ~/.ssh/<name>.pub. With an agent such as
          1Password holding the private half, IdentityFile can name the .pub.
        '';
      };
    };

    zsh = {
      rebuildFunctions = mkOption {
        type = types.str;
        description = ''
          zsh definitions of `nbu` (update the churny inputs, commit, build) and
          `nbs` (switch, upgrade mise, commit .tool-versions, push). The default
          suits a standalone Home Manager flake whose apps include
          build-switch; a nix-darwin or NixOS flake supplies its own.
        '';
      };
      platformInit = mkOption {
        type = types.str;
        default = lib.optionalString (isDarwin && cfg.homebrew.enable) ''
          # Homebrew, Apple Silicon prefix.
          eval "$(/opt/homebrew/bin/brew shellenv)"
        '';
        defaultText = lib.literalMD "Homebrew's `shellenv` on macOS when `dotfiles.homebrew.enable`";
        description = "zsh lines run just before the PATH is rebuilt.";
      };
      about = {
        entries = mkOption {
          type = types.listOf types.str;
          description = ''
            `about` entries, as "category|name|description", in display order.
            Categories nav, edit, nix, tool, ai, meta and mac get headings.
          '';
        };
        extra = mkOption {
          type = types.str;
          default = "";
          description = "zsh run inside `about` after `entries` is set, to append platform entries.";
        };
        source = mkOption {
          type = types.str;
          default = cfg.repo.flakeDir;
          defaultText = lib.literalExpression "config.dotfiles.repo.flakeDir";
          description = "Where `about` says the shell configuration comes from.";
        };
      };
    };

    homebrew.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Homebrew is installed at /opt/homebrew. Puts its bin, sbin and keg-only
        sqlite and llvm on PATH, and runs `brew shellenv`.
      '';
    };

    toolVersions = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/Users/me/dotfiles/.tool-versions";
      description = ''
        Absolute path of a writable .tool-versions to link at ~/.tool-versions,
        so `mise upgrade --bump` writes back into the checkout.
      '';
    };
  };
}
