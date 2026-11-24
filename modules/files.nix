# App configs linked from this repository, plus the per-person files
# options.nix describes (SSH public keys, the .tool-versions link).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dotfiles;
in
{
  imports = [ ./options.nix ];

  home.file = lib.mkMerge [
    (lib.mapAttrs' (name: key: lib.nameValuePair ".ssh/${name}.pub" { text = key; }) cfg.ssh.publicKeys)

    (lib.mkIf (cfg.toolVersions != null) {
      # Out-of-store symlink so `mise upgrade --bump` writes back to the
      # checkout directly, with no rebuild needed to bump a tool.
      ".tool-versions".source = pkgs.runCommandLocal "tool-versions-link" { } ''
        ln -s ${cfg.toolVersions} $out
      '';
    })

    {
      # Starship prompt config (raw TOML to preserve Nerd Font Unicode glyphs)
      ".config/starship.toml".source = ../config/starship.toml;

      # NvChad (Neovim config)
      ".config/nvim".source = ../config/nvim;

      # conda (a fallback for projects that insist on it; pixi is the
      # default): conda-forge only, no auto-activated base, envs in ~/.conda.
      ".config/conda/condarc".source = ../config/conda/condarc;
    }
  ];
}
