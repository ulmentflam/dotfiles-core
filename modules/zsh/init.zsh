      if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
      fi

      # Define variables for directories
      export PATH=$HOME/bin:$PATH
      export PATH=$HOME/.local/share/bin:$PATH

      # Remove history data we don't want to see
      export HISTORY_IGNORE="(pwd|ls|cd)"

      # Ripgrep alias
      alias search="rg -p --glob '!node_modules/*'"

      # Export ZSH background hilight color. 235 is dark grey
      export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#A7C080'

      # nvim is the universal alternate editor
      export ALTERNATE_EDITOR="nvim"

      # Go modules on by default (also set in mise globalConfig.env).
      export GO111MODULE=on

      @editor@

      # nix shortcuts
      shell() {
          nix-shell '<nixpkgs>' -A "$1"
      }

      # conda's shell hook costs a Python start, so load it on first
      # use instead of in every shell. The hook redefines `conda`, and
      # `conda activate` then works. Nothing is written to .zshrc.
      # macOS only in practice: on Linux conda lives inside
      # `conda-shell`, whose FHS profile sources the hook itself.
      if command -v conda >/dev/null 2>&1; then
        conda() {
          unfunction conda
          eval "$(command conda shell.zsh hook)"
          conda "$@"
        }
      fi

      @rebuildFunctions@

      about() {
          emulate -L zsh
          local query="$*"

          # Format: category|name|description (alphabetical within each category).
          # Add new aliases/functions here when you add them above.
          local entries='@aboutEntries@'

          @aboutExtra@if [ -n "$query" ]; then
            print -- "$entries" | grep -i --color=auto -- "$query" | while IFS='|' read -r cat name desc; do
              printf "  [%-4s] %-18s %s\n" "$cat" "$name" "$desc"
            done
            return
          fi

          print "## Shell entry points"
          [ -L "$HOME/.zshrc" ]  && print "  ~/.zshrc  -> $(readlink "$HOME/.zshrc")"
          [ -L "$HOME/.bashrc" ] && print "  ~/.bashrc -> $(readlink "$HOME/.bashrc")"
          print "  source:   @aboutSource@"

          local last_cat=""
          print -- "$entries" | while IFS='|' read -r cat name desc; do
            if [ "$cat" != "$last_cat" ]; then
              last_cat="$cat"
              case "$cat" in
                nav)  print "\n## Navigation" ;;
                edit) print "\n## Edit configs" ;;
                nix)  print "\n## Nix" ;;
                tool) print "\n## CLI tools" ;;
                ai)   print "\n## AI" ;;
                meta) print "\n## Meta" ;;
                mac)  print "\n## macOS only" ;;
                *)    print "\n## $cat" ;;
              esac
            fi
            printf "  %-18s %s\n" "$name" "$desc"
          done
          print ""
          print "Tip: about <pattern>   filter by name/desc/category (case-insensitive)"
      }

      # pnpm is a javascript package manager
      alias pn=pnpm
      alias px=pnpx

      # Use difftastic, syntax-aware diffing
      alias diff=difft

      # Always color ls and group directories
      alias ls='ls --color=auto'

      @platformInit@

      #================== Core Sources and Paths =================

      @pathSetup@

      # mise is configured via programs.mise in home-manager

      #=================== Evals ===================
      eval "$(pay-respects zsh --alias)"
      alias fuck=f

      #================= Terminal Toolings =============

      if [[ "$TERM_PROGRAM" == "ghostty" ]]; then
          export TERM=xterm-256color
      fi

      #================= completion (carapace + fzf-tab) =================
      # carapace takes over the commands it has completers for (git,
      # kubectl, jq, ...); everything else keeps its own zsh completion.
      # Inlined rather than through enableZshIntegration so it runs
      # after compinit and ahead of the mise block: its init prepends
      # its own bin directory to PATH, which must not land in front of
      # the pinned runtimes.
      source <(@carapace@ _carapace zsh)
      # Group headers for fzf-tab's group switching (< and >). With
      # menu off, Tab goes straight to fzf-tab instead of zsh's menu.
      zstyle ':completion:*' format '[%d]'
      zstyle ':completion:*' menu no
      zstyle ':completion:*:git-checkout:*' sort false
      zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -1 --color=always $realpath'

      #================= mise (after every PATH edit) =================
      # Activation prepends the pinned runtimes once, and later hook-env
      # runs never move them back to the front. So it must follow the
      # path_helper + Homebrew block above; activated any earlier,
      # Homebrew's dependency python3 and node shadow the pinned ones.
      eval "$(@mise@ activate zsh)"

      #================= zoxide (must be last) =================
      # Initialized here, not via programs.zoxide.enableZshIntegration, so it
      # runs after oh-my-zsh, mise and compinit re-runs.
      #
      # _ZO_DOCTOR=0 silences the doctor's false positive. The doctor does a
      # *syntactic* scan of .zshrc and warns whenever any non-comment line
      # appears after `zoxide init` — but home-manager always emits its
      # shellAliases + zsh-syntax-highlighting source AFTER initContent, so
      # there's no way to be syntactically last without abandoning those
      # home-manager options. The doctor's actual concern (was `cd` redefined?)
      # does not apply here — none of the trailing lines redefine cd.
      # Per zoxide docs: "This message does not affect zoxide's functionality."
      export _ZO_DOCTOR=0
      if command -v zoxide >/dev/null 2>&1; then
        eval "$(zoxide init zsh --cmd cd)"
      fi
