# dotfiles-core

A Home Manager configuration for macOS and Linux, packaged as a flake other flakes build on. It carries a shell, git, editors, CLI tools and AI-agent tooling, with nothing personal in it: identity, signing keys, SSH hosts and paths are options a consuming flake sets.

- **Shell**: zsh with oh-my-zsh, starship (everforest powerline), fzf-tab, carapace completions, zoxide, mise, direnv with nix-direnv, pay-respects and comma.
- **Tools**: git (SSH signing optional), vim, NvChad for neovim, tmux, and a CLI package list (`lib/packages.nix`).
- **AI tooling**: Claude Code, Codex and Antigravity CLI through their native self-updating installers, a TDD agent ensemble for Claude Code and OpenCode, skills linked into all four tools, and a generated per-machine instruction file every tool loads.
- **A review gate for third-party skills**: nothing from outside this repository is linked until an agent has audited the exact locked revision.

## Use it on a machine

Install Nix ([Determinate](https://install.determinate.systems) works), then start a flake of your own from the template:

```bash
mkdir ~/dotfiles-work && cd ~/dotfiles-work
nix flake init -t github:ulmentflam/dotfiles-core#overlay
git init && git add -A
$EDITOR home.nix            # username, name, email, signing, apps
nix run .#build-switch      # home-manager switch; conflicting files are kept as *.backup
nix run .#touchid-sudo      # once, macOS: Touch ID for sudo (writes /etc/pam.d/sudo_local)
exec zsh
```

Your flake holds what is yours: `home.nix`, `.tool-versions`, and its `flake.lock`. Keep it local or push it to a private repository; it never needs to be public, and this one never needs to know about it. Afterwards:

| Command | What it does |
|---------|--------------|
| `nbs` | Switch, apply the Brewfile, upgrade mise and commit `.tool-versions`, push if the checkout has an upstream |
| `nb` | Build without switching (`nix run .#build`) |
| `nfu` / `nfa` | Update the churny inputs / every input, commit `flake.lock` |
| `about` | List every alias and function |
| `nix run .#touchid-sudo` | macOS, once: Touch ID for `sudo`, with `pam_reattach` so it works in tmux. Leaves an existing Touch ID setup alone; `--check` only reports |

The template is a single-user Home Manager flake, so it suits a second macOS account or a work machine as well as a personal one: every path derives from `home.username`.

### GUI apps on macOS

`modules/darwin-apps.nix` offers two sources:

- **`dotfiles.darwin.brewfile`** writes `~/.config/homebrew/Brewfile` and points `HOMEBREW_BUNDLE_FILE` at it, so plain `brew bundle` applies it (`nbs` does after each switch). Use this for most GUI apps. Casks install into `/Applications` and keep their own auto-updaters, so browser and chat-client security fixes land when the vendor ships them. A stable path and signature also keep macOS privacy grants (Accessibility, Screen Recording) across updates. Apps that only work from `/Applications`, such as 1Password's browser integration, need it. Nothing is uninstalled, so apps from device management or installed by hand stay put; adopt an existing app with `brew install --cask --adopt <cask>`.
- **`dotfiles.darwin.apps`** installs nixpkgs packages and copies them into `~/Applications/Home Manager Apps`. They are pinned and roll back with the generation. Prefer vendor-built `-bin` packages: an app nixpkgs compiles is ad-hoc signed and loses its privacy grants on every rebuild.

The template's Brewfile includes Maccy and Thaw, open-source stand-ins for Paste and Bartender. With the `maccy` cask listed, `dotfiles.darwin.maccy.enable` gives Maccy Paste's interaction: Command-Shift-V opens the history and choosing an item pastes it. Each key is written with `defaults write`; Home Manager's `targets.darwin.defaults` would import the whole domain and reset Maccy's other settings. Thaw needs Accessibility and Screen Recording, which macOS asks for on first launch.

CLI tools come from Nix either way (`dotfiles.packages.homebrewCli = false`). Drop ones you don't want with `dotfiles.packages.exclude`; a name that matches nothing fails evaluation.

## Use it from nix-darwin or NixOS

A system flake imports the modules it wants and sets the options itself:

```nix
inputs.dotfiles-core = {
  url = "github:ulmentflam/dotfiles-core";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.home-manager.follows = "home-manager";
};

# inside home-manager.users.<name>:
{ config, pkgs, lib, ... }: {
  imports = with dotfiles-core.homeModules; [ options files ai-files claude-code codex git-hooks ];
  dotfiles = { user = { name = "..."; email = "..."; }; repo.path = "~/dotfiles"; ai.skills = dotfiles-core.lib.skills; };
  dotfiles.zsh.rebuildFunctions = "...";   # your nbu / nbs, with sudo and your switch command
  programs = dotfiles-core.lib.programs { inherit config pkgs lib; };
}
```

`lib.programs` is a function rather than a module on purpose. Home Manager orders same-priority zsh init lines by module, and assigning the attrset in your own module keeps its lines where they would sit if you had written them there. `homeModules.programs` is the module form, with standalone defaults for `nbs` and `about`.

## Layout

| Path | What |
|------|------|
| `flake.nix` | Inputs, `homeModules`, `lib`, the placeholder `homeConfigurations`, apps, the `overlay` template |
| `lib/` | `mkHome`, `mkHomeApps`, `mkSkills` (the review gate), `programs`, `packages`, `shellAliases`, `aiFiles` |
| `modules/options.nix` | Every per-person value; identity options have no default |
| `modules/programs.nix`, `modules/zsh/` | The programs module; `init.zsh` is the interactive zsh block, a template with `@slot@` markers |
| `modules/*.nix` | Files, packages, AI tools, git hooks, OpenCode settings, macOS apps, the instruction file |
| `modules/skills/` | Third-party skill sources, approved reviews, the reviewer's prompt |
| `config/` | starship, NvChad, conda |
| `agents/` | TDD ensemble for Claude Code and OpenCode |
| `skills/` | Local skills |
| `templates/overlay/` | A machine's own flake |
| `smoke-tests/` | Eval-only checks (`all.sh`) |

## Options

All under `dotfiles.`; see `modules/options.nix` and each module for the full descriptions.

| Option | Default | |
|--------|---------|--|
| `user.name`, `user.email` | required | Git identity |
| `repo.path`, `repo.flakeDir` | required, `repo.path` | The checkout, for aliases, `nbs` and the git hook |
| `repo.churnyInputs` | `[ "nix-index-database" ]` | What `nfu` / `nbu` update |
| `editor.init`, `editor.git` | nvim | `$EDITOR` lines, git's `core.editor` |
| `git.signing.key`, `.signer` | `null` | SSH commit signing; the signer defaults to `ssh-keygen` |
| `ssh.identityAgent`, `.includes`, `.hosts`, `.publicKeys` | none | ssh_config and `~/.ssh/*.pub` |
| `homebrew.enable` | `false` (on with a Brewfile) | Homebrew on PATH, `brew shellenv` |
| `toolVersions` | `null` | Writable `.tool-versions` linked at `~/.tool-versions` |
| `packages.enable`, `.homebrewCli`, `.exclude` | `true`, `false`, `[ ]` | The CLI package list, and names to leave out of it |
| `darwin.brewfile.*`, `darwin.apps` | off, `[ ]` | macOS GUI apps |
| `darwin.maccy.enable`, `darwin.touchIdSudo.check` | with the `maccy` cask, `true` | Maccy's Paste-style shortcut; an activation note when Touch ID for sudo is off |
| `ai.skills`, `ai.agents.*` | core skills, TDD agents | What is linked into the AI tools |
| `ai.docs.prose`, `.extraSections`, `.toolVersionsFile` | empty | The generated instruction file |
| `ai.opencode.settings` | `{ }` | Defaults merged into `opencode.json` |
| `gitHooks.repos` | `[ repo.path ]` | Checkouts whose `core.hooksPath` is set to `.githooks/` |
| `zsh.rebuildFunctions`, `.platformInit`, `.about.*` | standalone flavour | Lines a system flake replaces |

## Third-party skills

Skill repositories are `flake = false` inputs listed in `modules/skills/sources.nix`. `modules/skills/reviews.json` records the `narHash` each review approved, and `lib.mkSkills` refuses a lock that pins anything else, so evaluation fails rather than linking content nobody read.

```bash
nix run .#skills-review -- <name>       # review a source at its locked revision
nix run .#skills-review -- --update     # bump every skill input, review what moved
```

The reviewer fetches the locked revision and runs a pattern scan: injection phrases, hidden Unicode, download-and-execute, credential access, persistence, agent-config tampering and non-loopback binds. Claude then audits the full tree on a first review, or the diff since the approved revision. It runs with `--safe-mode` and only Read, Grep and Glob, so the content under review can neither load nor act. A `high` finding fails the review whatever the verdict says. A pass is recorded after a y/N prompt (or `--approve`), and the report is committed as `modules/skills/reviews/<name>.md`.

A consumer adds its own local skills without weakening the gate: `dotfiles-core.lib.mkSkills { locals = [ dotfiles-core.lib.skillsDir ./skills ]; }`.

## Development

```bash
nix develop                    # nixfmt, statix, deadnix, gitleaks
nix fmt .                      # RFC 166; the tree is clean
statix check . && deadnix .
bash smoke-tests/all.sh        # SMOKE_TMPDIR picks where test scratch dirs go
gitleaks git .                 # before every push
```

`smoke-tests/no-personal.sh` fails on personal identifiers in tracked files and the rendered configuration; add your own to `PERSONAL_PATTERNS` before pushing. A pre-commit hook in `.githooks/` rejects unformatted staged `.nix` files once `modules/git-hooks.nix` points the checkout at it.

## License

MIT, see [LICENSE](./LICENSE). `config/nvim` (NvChad starter) and `skills/demo-gif` keep their own licenses, alongside them.
