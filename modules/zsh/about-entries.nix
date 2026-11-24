# Default `about` entries: what the core aliases and functions do.
# Format: category|name|description, in display order.
{
  path,
  flakeDir,
  gitConfigFile,
  brewfile,
}:

[
  "nav|dotfiles|cd to ${path}"
  "nav|home|cd to home directory"
  "nav|nc|cd to ${flakeDir}"
  "nav|nix-config|cd to ${flakeDir} (long form of nc)"
  "edit|awsconfig|open ~/.aws/config in $EDITOR"
  "edit|gitconfig|open ${gitConfigFile} in $EDITOR"
  "edit|tool-versions|open ~/.tool-versions in $EDITOR"
  "nix|nb|build ${flakeDir} without activating, from any directory (nix run .#build)"
  "nix|nbs|FN: build-switch + mise upgrade + commit + push (most common)"
  "nix|nbu|FN: update churny flake inputs, commit, build"
  "nix|nfa|update all flake inputs + commit flake.lock"
  "nix|nfu|update churny flake inputs + commit flake.lock"
  "nix|aidocs|print the Nix-generated per-machine AI instruction file (~/CLAUDE.local.md)"
  "nix|shell|FN: nix-shell <nixpkgs> -A \"$1\""
  "nix|upgrade|mise upgrade"
  "tool|,|comma: run a nixpkgs program without installing it (, cowsay hi)"
]
++ (
  if brewfile then
    [ "tool|brew bundle|install and upgrade the Brewfile's apps (~/.config/homebrew/Brewfile)" ]
  else
    [ ]
)
++ [
  "tool|diff|difftastic (syntax-aware diff)"
  "tool|direnv|per-directory env; `use flake` in .envrc is cached by nix-direnv"
  "tool|fuck|pay-respects (correct previous command)"
  "tool|ls|ls --color=auto"
  "tool|pn|pnpm"
  "tool|px|pnpx"
  "tool|search|ripgrep, ignoring node_modules"
  "ai|ayolo|agy --dangerously-skip-permissions"
  "ai|cyolo|codex --dangerously-bypass-approvals-and-sandbox"
  "ai|yolo|claude --dangerously-skip-permissions"
  "meta|about|this help (about <pattern> to filter)"
]
