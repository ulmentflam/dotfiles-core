# The CLI package list, as a function so a nix-darwin or NixOS consumer can
# reuse it in its own home.packages without the module (modules/packages.nix).
#
# `homebrewCli`: on macOS, the tools whose nixpkgs release trails Homebrew's
# come from Homebrew formulae instead (the consumer declares them). Off, Nix
# provides them on macOS too, which is what a machine without a nix-darwin
# Homebrew module wants: one pinned, rollbackable source for every CLI.
{
  pkgs,
  homebrewCli ? false,
}:

with pkgs;
[
  # General packages for development and system management
  autoconf
  aspell
  aspellDicts.en
  bash-completion
  # bat - managed by programs.bat in modules/programs.nix
  # btop - managed by programs.btop in modules/programs.nix
  coreutils
  gptfdisk # gdisk / sgdisk / cgdisk
  killall
  fastfetch
  openssh
  wget
  zip
  kubernetes-helm
  kubectl
  nghttp2
  tflint
  tor
  ffmpeg
  # fzf - managed by programs.fzf in modules/programs.nix

  # Build essentials
  gnumake
  cmake
  ninja
  libtool
  bison
  flex

  # Encryption and security tools
  age
  age-plugin-yubikey
  libfido2

  # Media-related packages
  dejavu_fonts
  # fd - managed by programs.fd in modules/programs.nix
  font-awesome
  hack-font
  noto-fonts
  noto-fonts-color-emoji
  nerd-fonts.meslo-lg

  # Editors
  neovim

  # Node.js development tools

  # Text and terminal utilities
  asciidoctor
  ssm-session-manager-plugin
  iftop
  jetbrains-mono
  jq
  difftastic # `diff` alias
  # ripgrep - managed by programs.ripgrep in modules/programs.nix
  tree
  # tmux - managed by programs.tmux in modules/programs.nix
  unzip
  pay-respects
  # nix-index - managed by programs.nix-index + nix-index-database flake module
  # in modules/programs.nix and imported by homeModules.default. The module
  # provides `nix-index-with-full-db` (binary + prebuilt daily db), so adding
  # plain `nix-index` here would create a duplicate `bin/nix-locate` in
  # home-manager's buildEnv.
  # zoxide - managed by programs.zoxide in modules/programs.nix
  zsh-completions
  zsh-autosuggestions
  zsh-syntax-highlighting
  git-filter-repo

  # PDF tools
  poppler-utils # pdftotext, pdftoppm, ...
  qpdf

  # Terminal recording for the demo-gif skill
  vhs

  # Speech-to-text (Metal + CoreML on Apple Silicon)
  whisper-cpp

  # Python packages

  # Nix tooling
  nh
  # nixfmt implements RFC 166, the official Nix format. Needs to be on PATH
  # (not just in the dev shell) because the dotfiles pre-commit hook shells
  # out to it - see modules/git-hooks.nix.
  nixfmt
  statix
  deadnix

  # Cloud drive sync (rclone remotes: Google Drive, iCloud Drive, S3, ...)
  rclone
]
# Tools nixpkgs ships behind Homebrew's release. Linux always takes them from
# Nix; macOS takes them from Homebrew formulae when `homebrewCli` is set.
++ lib.optionals (stdenv.hostPlatform.isLinux || !homebrewCli) [
  # Lag Homebrew
  awscli2
  brev-cli
  cloudflared # Cloudflare Tunnel
  gh
  git-lfs
  gnupg
  hunspell
  just
  nmap
  opencode
  parallel
  sqlite
  trivy # IaC / container scanning; replaces the deprecated tfsec
  tree-sitter
  yq # python-yq, the jq wrapper
  automake
  pkg-config # macOS: pkgconf, which finds Homebrew's libraries

  # LLVM (non-conflicting bits: clang and lldb come from the system toolchain).
  # On macOS these sit behind Xcode's clang either way.
  clang-tools
  llvm
  lld

  # Official 7-Zip with RAR extraction (unfree). macOS: the sevenzip formula.
  _7zz-rar
]
# Linux only: TeX (macOS uses the mactex cask) and tools with no macOS use.
++ lib.optionals stdenv.hostPlatform.isLinux [
  # TeX - full scheme so no build hits a missing .sty. macOS: the mactex cask.
  texliveFull

  # No macOS use: GNU binutils would shadow Apple's Mach-O ar/strip/nm,
  # macOS ships nc, and Ghostty is the macOS terminal.
  binutils
  netcat
  alacritty

  # conda for projects that require it (pixi is the default). Run
  # `conda-shell`: an FHS env that installs Miniconda to ~/.conda on first
  # use. macOS gets the miniforge cask instead; nixpkgs' conda is Linux-only.
  conda
]
