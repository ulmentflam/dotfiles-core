# The programs Home Manager configures, as the attrset for `programs`: zsh,
# git, vim, ssh, tmux, fzf, carapace, zoxide, bat, btop, fd, ripgrep, mise,
# starship, direnv and nix-index. Everything personal comes from
# config.dotfiles (modules/options.nix).
#
# A function rather than a module so a consumer can assign it to `programs`
# in its own module, at the position its definitions always had: Home Manager
# orders same-priority zsh init lines by module, so importing this as a
# module of its own would move the starship and direnv hooks around it.
# modules/programs.nix is the module form.
#
# The interactive zsh block is modules/zsh/init.zsh, a template with @slot@
# markers filled below. It is a file rather than a Nix string so that a
# consumer can move its own lines into the slots without the indentation Nix
# strips from indented strings shifting every other line.
{
  config,
  pkgs,
  lib,
}:

let
  cfg = config.dotfiles;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  aliases = import ./shell-aliases.nix {
    inherit (cfg.repo) churnyInputs gitConfigFile;
    repo = cfg.repo.path;
    inherit (cfg.repo) flakeDir;
  };

  aiQuietDetect = ''
    if [[ -n "''${CLAUDECODE:-}''${CLAUDE_CODE_ENTRYPOINT:-}''${OPENCODE:-}''${OPENCODE_SESSION_ID:-}''${CODEX_ENV_PYTHON_VERSION:-}''${CODEX_AGENT:-}''${GEMINI_CLI:-}''${GEMINI_SDK_LANGUAGE:-}''${ANTIGRAVITY_CLI:-}" ]]; then
      export AI_QUIET=1
    fi
  '';

  darwinPathSetupHomebrew = ''
    # Build path with macOS path_helper before assigning custom PATHs
    if [ -x /usr/libexec/path_helper ]; then
        eval `/usr/libexec/path_helper -s`
    fi

    # path_helper moves /etc/paths (/usr/local/bin, /usr/bin, /bin, ...) to the
    # front and everything else behind it, so Apple's git, vim, ssh, make and
    # BSD coreutils silently shadowed the Nix ones, and ~/.local/bin lost the
    # lead local-bin-path.nix gives it. Rebuild the front: the user's own bin
    # dirs, Homebrew (Apple Silicon prefix, pinned rather than asked of brew,
    # since that asks whichever brew wins this PATH), keg-only sqlite, then the
    # Nix profiles, all ahead of the system directories. llvm is keg-only too
    # and goes last, so Xcode's clang/lldb keep winning and llvm supplies only
    # what Xcode lacks (clangd, clang-format, clang-tidy, llvm-*). mise
    # re-prepends its own paths at each prompt, so it still leads.
    export PATH=$HOME/.local/bin:$HOME/.local/share/bin:$HOME/bin:/opt/homebrew/sbin:/opt/homebrew/bin:/opt/homebrew/opt/sqlite/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH:/opt/homebrew/opt/llvm/bin
    typeset -U path
  '';
  darwinPathSetupPlain = ''
    # Build path with macOS path_helper before assigning custom PATHs
    if [ -x /usr/libexec/path_helper ]; then
        eval `/usr/libexec/path_helper -s`
    fi

    # path_helper moves /etc/paths (/usr/local/bin, /usr/bin, /bin, ...) to the
    # front and everything else behind it, so Apple's git, vim, ssh, make and
    # BSD coreutils would shadow the Nix ones, and ~/.local/bin would lose the
    # lead local-bin-path.nix gives it. Rebuild the front: the user's own bin
    # dirs, then the Nix profiles, all ahead of the system directories. mise
    # re-prepends its own paths at each prompt, so it still leads.
    export PATH=$HOME/.local/bin:$HOME/.local/share/bin:$HOME/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH
    typeset -U path
  '';

  darwinPathSetup = lib.optionalString isDarwin (
    if cfg.homebrew.enable then darwinPathSetupHomebrew else darwinPathSetupPlain
  );

  initBlock =
    builtins.replaceStrings
      [
        "@editor@"
        "@rebuildFunctions@"
        "@aboutEntries@"
        "@aboutExtra@"
        "@aboutSource@"
        "@platformInit@"
        "@pathSetup@"
        "@carapace@"
        "@mise@"
      ]
      [
        cfg.editor.init
        cfg.zsh.rebuildFunctions
        (lib.concatStringsSep "\n" cfg.zsh.about.entries)
        cfg.zsh.about.extra
        cfg.zsh.about.source
        cfg.zsh.platformInit
        darwinPathSetup
        (lib.getExe pkgs.carapace)
        (lib.getExe pkgs.mise)
      ]
      (builtins.readFile ../modules/zsh/init.zsh);

in
{
  # Shared shell configuration
  zsh = {
    enable = true;
    autocd = false;
    cdpath = [ "~/.local/share/src" ];
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;
    oh-my-zsh = {
      enable = true;
      # No "mise" plugin: it runs `mise activate` during oh-my-zsh's early
      # load, ahead of the Homebrew PATH edits. Activation is inlined late
      # in initContent instead, and the mise package ships its own _mise.
      plugins = [ "git" ];
      theme = "";
      # oh-my-zsh names its compdump after the short hostname, which macOS
      # bumps (-2, -3, ...) on Bonjour name conflicts. Each bump forces a cold
      # rebuild, and shells starting together then read a half-written dump.
      extraConfig = ''
        mkdir -p "''${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
        ZSH_COMPDUMP="''${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-$ZSH_VERSION"
      '';
    };
    shellAliases = aliases;
    # fzf-tab turns the Tab completion menu into an fzf picker. Home Manager
    # sources plugins after oh-my-zsh's compinit, which fzf-tab needs, and
    # before fzf's own key bindings. fzf then takes Tab over but keeps
    # fzf-tab as its fallback, so `**<Tab>` stays fzf's and every other
    # completion goes through fzf-tab.
    plugins = [
      {
        name = "fzf-tab";
        src = "${pkgs.zsh-fzf-tab}/share/fzf-tab";
      }
    ];
    # envExtra lands in .zshenv, which zsh sources for *every* invocation:
    # interactive, non-interactive, login, non-login. initContent lands in
    # .zshrc, which only runs for interactive shells. The AI agent detection
    # must be in .zshenv so it fires for non-interactive shells spawned by
    # the agents' shell tools, which is exactly where the chatty echos
    # should be suppressed.
    envExtra = ''
      #=============== AI agent quiet mode (always-on detection) ===============
      ${aiQuietDetect}

      #=============== GitHub token (mise + anything else env-driven) ===============
      # Written at home-manager activation by modules/shared/github-token.nix
      # from `gh auth token`. Missing on first bootstrap before `gh auth login`.
      [ -f "$HOME/.config/github-token.env" ] && . "$HOME/.config/github-token.env"
    '';
    initContent = lib.mkMerge [
      # Runs before home-manager sources oh-my-zsh (which calls compinit), so
      # the completion gets picked up without a second compinit pass.
      (lib.mkOrder 550 ''
        #================ Docker zsh completions =================
        # https://docs.docker.com/engine/cli/completion/
        # Lazy-generated on first shell after docker is on PATH. Delete
        # ~/.docker/completions/_docker to refresh after a docker upgrade.
        if command -v docker >/dev/null 2>&1; then
          if [[ ! -s "$HOME/.docker/completions/_docker" ]]; then
            mkdir -p "$HOME/.docker/completions"
            docker completion zsh > "$HOME/.docker/completions/_docker" 2>/dev/null
          fi
          fpath=("$HOME/.docker/completions" $fpath)
        fi
      '')
      initBlock
    ];
  };

  # The whole git config lives here.
  git = {
    enable = true;
    ignores = [
      "*.swp"
      "*~"
      ".DS_Store"
      "**/.claude/settings.local.json"
    ];
    lfs = {
      enable = true;
    };
    signing = lib.mkIf (cfg.git.signing.key != null) (
      {
        format = "ssh";
        inherit (cfg.git.signing) key;
        signByDefault = true;
      }
      // lib.optionalAttrs (cfg.git.signing.signer != null) {
        inherit (cfg.git.signing) signer;
      }
    );
    settings = {
      user.name = cfg.user.name;
      user.email = cfg.user.email;
      init.defaultBranch = "main";
      core = {
        editor = cfg.editor.git;
        autocrlf = "input";
      };
      pull.rebase = true;
      rebase.autoStash = true;
    };
  };

  vim = {
    enable = true;
    # vim-full defaults to a GTK2 GUI on Darwin, an X11 gvim nobody launches
    # here, and vim 9.2.1164's image.c reads gui.scale, which the GTK2 build
    # lacks, so it fails to compile. Build terminal-only vim on macOS.
    packageConfigurable = lib.mkIf isDarwin (pkgs.vim-full.override { guiSupport = "none"; });
    plugins = with pkgs.vimPlugins; [
      vim-airline
      vim-airline-themes
      vim-startify
      vim-tmux-navigator
    ];
    settings = {
      ignorecase = true;
    };
    extraConfig = ''
      "" General
      set number
      set history=1000
      set nocompatible
      set modelines=0
      set encoding=utf-8
      set scrolloff=3
      set showmode
      set showcmd
      set hidden
      set wildmenu
      set wildmode=list:longest
      set cursorline
      set ttyfast
      set nowrap
      set ruler
      set backspace=indent,eol,start
      set laststatus=2
      set clipboard=autoselect

      " Dir stuff
      set nobackup
      set nowritebackup
      set noswapfile
      set backupdir=~/.config/vim/backups
      set directory=~/.config/vim/swap

      " Relative line numbers for easy movement
      set relativenumber
      set rnu

      "" Whitespace rules
      set tabstop=8
      set shiftwidth=2
      set softtabstop=2
      set expandtab

      "" Searching
      set incsearch
      set gdefault

      "" Statusbar
      set nocompatible " Disable vi-compatibility
      set laststatus=2 " Always show the statusline
      let g:airline_theme='bubblegum'
      let g:airline_powerline_fonts = 1

      "" Local keys and such
      let mapleader=","
      let maplocalleader=" "

      "" Change cursor on mode
      :autocmd InsertEnter * set cul
      :autocmd InsertLeave * set nocul

      "" File-type highlighting and configuration
      syntax on
      filetype on
      filetype plugin on
      filetype indent on

      "" Paste from clipboard
      nnoremap <Leader>, "+gP

      "" Copy from clipboard
      xnoremap <Leader>. "+y

      "" Move cursor by display lines when wrapping
      nnoremap j gj
      nnoremap k gk

      "" Map leader-q to quit out of window
      nnoremap <leader>q :q<cr>

      "" Move around split
      nnoremap <C-h> <C-w>h
      nnoremap <C-j> <C-w>j
      nnoremap <C-k> <C-w>k
      nnoremap <C-l> <C-w>l

      "" Easier to yank entire line
      nnoremap Y y$

      "" Move buffers
      nnoremap <tab> :bnext<cr>
      nnoremap <S-tab> :bprev<cr>

      "" Like a boss, sudo AFTER opening the file to write
      cmap w!! w !sudo tee % >/dev/null

      let g:startify_lists = [
        \ { 'type': 'dir',       'header': ['   Current Directory '. getcwd()] },
        \ { 'type': 'sessions',  'header': ['   Sessions']       },
        \ { 'type': 'bookmarks', 'header': ['   Bookmarks']      }
        \ ]

      let g:startify_bookmarks = [
        \ '~/.local/share/src',
        \ ]

      let g:airline_theme='bubblegum'
      let g:airline_powerline_fonts = 1
    '';
  };

  ssh = {
    enable = true;
    enableDefaultConfig = false;
    inherit (cfg.ssh) includes;
    # programs.ssh.settings: PascalCase OpenSSH directive names, one block per
    # host, the global "*" block just another entry.
    settings =
      lib.optionalAttrs (cfg.ssh.identityAgent != null) {
        "*" = {
          IdentityAgent = cfg.ssh.identityAgent;
        };
      }
      // cfg.ssh.hosts;
  };

  tmux = {
    enable = true;
    plugins = with pkgs.tmuxPlugins; [
      vim-tmux-navigator
      sensible
      yank
      prefix-highlight
      {
        plugin = power-theme;
        extraConfig = ''
          set -g @tmux_power_theme 'everforest'
        '';
      }
      {
        plugin = resurrect; # Used by tmux-continuum

        # Use XDG data directory
        # https://github.com/tmux-plugins/tmux-resurrect/issues/348
        extraConfig = ''
          set -g @resurrect-dir '$HOME/.cache/tmux/resurrect'
          set -g @resurrect-capture-pane-contents 'on'
          set -g @resurrect-pane-contents-area 'visible'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '5' # minutes
        '';
      }
    ];
    terminal = "screen-256color";
    prefix = "C-b";
    escapeTime = 10;
    historyLimit = 50000;
    extraConfig = ''
      # True color support (needed for Starship/Nerd Font colors in tmux)
      set -ag terminal-overrides ",xterm-256color:RGB"
      set -ag terminal-overrides ",alacritty:RGB"
      set -ag terminal-overrides ",xterm-ghostty:RGB"

      # Remove Vim mode delays
      set -g focus-events on

      # Enable full mouse support
      set -g mouse on

      # set shell
      set -gu default-command
      set -g default-shell "$SHELL"

      # Start windows and panes at one, not zero
      set -g base-index 1
      setw -g pane-base-index 1

      # -----------------------------------------------------------------------------
      # Vim navigation bindings
      # -----------------------------------------------------------------------------

      # Smart pane switching with awareness of Vim splits.
      # This is copy paste from https://github.com/christoomey/vim-tmux-navigator
      is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
        | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|n?vim?x?)(diff)?$'"
      bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h'  'select-pane -L'
      bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j'  'select-pane -D'
      bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k'  'select-pane -U'
      bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l'  'select-pane -R'
      tmux_version='$(tmux -V | sed -En "s/^tmux ([0-9]+(.[0-9]+)?).*/\1/p")'
      if-shell -b '[ "$(echo "$tmux_version < 3.0" | bc)" = 1 ]' \
        "bind-key -n 'C-\\' if-shell \"$is_vim\" 'send-keys C-\\'  'select-pane -l'"
      if-shell -b '[ "$(echo "$tmux_version >= 3.0" | bc)" = 1 ]' \
        "bind-key -n 'C-\\' if-shell \"$is_vim\" 'send-keys C-\\\\'  'select-pane -l'"

      bind-key -T copy-mode-vi 'C-h' select-pane -L
      bind-key -T copy-mode-vi 'C-j' select-pane -D
      bind-key -T copy-mode-vi 'C-k' select-pane -U
      bind-key -T copy-mode-vi 'C-l' select-pane -R
      bind-key -T copy-mode-vi 'C-\' select-pane -l
    '';
  };

  # Declarative tool configurations (migrated from packages.nix)
  fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # Completion engine behind fzf-tab; the zsh hook is inlined in initContent
  # ahead of mise, see the note there.
  carapace = {
    enable = true;
    enableZshIntegration = false;
  };

  zoxide = {
    enable = true;
    # zsh integration is inlined at the end of initContent below so that zoxide's
    # `cd` binding wins over anything sourced after home-manager's early-init slot
    # (oh-my-zsh plugins, mise, compinit re-runs, etc.). Per zoxide's doctor:
    # https://github.com/ajeetdsouza/zoxide#installation - init must be last.
    enableZshIntegration = false;
    options = [
      "--cmd"
      "cd"
    ];
  };

  bat = {
    enable = true;
  };

  btop = {
    enable = true;
  };

  fd = {
    enable = true;
  };

  ripgrep = {
    enable = true;
  };

  # Runtime version manager (replaces ASDF)
  mise = {
    enable = true;
    # Inlined late in initContent instead, see the note there.
    enableZshIntegration = false;

    # Stock package, on purpose. This once carried an overrideAttrs that
    # skipped the http:: tests because the aarch64-darwin build was not in
    # any cache and its checkPhase failed locally. Any override changes the
    # derivation hash, which guarantees a cache miss and a from-source build
    # on every bump. The stock derivation is in cache.nixos.org again; if it
    # ever regresses, prefer waiting for the cache over re-adding an override.
    globalConfig = {
      env = {
        GO111MODULE = "on";
      };
      settings = {
        python.github_attestations = false;
        # pixi (github backend) trips a Sigstore TSA timestamp verification
        # failure ("no certificate matches issuer and serial number") on
        # install/bump. Checksum + SLSA provenance verification still run.
        github.github_attestations = false;
        # Use jdx's precompiled ruby tarballs instead of compiling via
        # ruby-build. Source builds break on this machine: Apple ld-1267
        # (Xcode 26 / macOS 26) fails linking the extension bundles against
        # the freshly built libruby with
        #   ld: load command #12 string extends beyond end of load command
        #       in './libruby.4.0.dylib'
        # which kills `make` and leaves the bump unlanded. Every `nbs` then
        # re-downloaded and re-compiled ruby on each loop iteration.
        # mise makes precompiled the default in 2026.8.0; pin it explicitly so
        # the behavior is the same regardless of which mise version is active.
        ruby.compile = false;
      };
    };
  };

  # Shell prompt - everforest powerline style (replaces powerlevel10k)
  # Uses settings = {} to skip TOML generation; config managed via home.file
  starship = {
    enable = true;
    enableZshIntegration = true;
    # Stock package. See the note on `mise` above: the lld-linked override
    # that used to live here forced a from-source build on every rebuild
    # once the stock aarch64-darwin derivation was back in the cache.
  };

  # Per-directory environments. nix-direnv caches `use flake` / `use nix`
  # shells in the store so entering a project dir is instant after the first
  # load and survives garbage collection.
  direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # nix-locate index - backs pay-respects' "did you mean / install via nix"
  # suggestions on command-not-found. Without this, every typo prints a noisy
  # "I/O error: No such file or directory" from nix-locate.
  # The pre-built daily-updated database is supplied by the `nix-index-database`
  # flake input, whose Home Manager module homeModules.default imports. No
  # manual `nix-index` step required.
  # zsh integration is off because pay-respects already owns the
  # command_not_found_handler hook; we only want the binary + db on PATH.
  nix-index = {
    enable = true;
    enableZshIntegration = false;
  };

  # `, <cmd>` runs a program from nixpkgs without installing it, backed by the
  # same prebuilt nix-index database.
  nix-index-database.comma.enable = true;
}
