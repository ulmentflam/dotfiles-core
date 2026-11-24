# Sourced by every smoke test. Eval-only helpers; nothing here builds.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
ROOT=$PWD
FLAKE="git+file://$ROOT"
NIX=(nix --extra-experimental-features "nix-command flakes")

fail() {
  echo "FAIL: $1"
  exit 1
}

# eval_raw '<nix expression with `f` bound to this flake>'
eval_raw() {
  "${NIX[@]}" eval --impure --raw --expr "let f = builtins.getFlake \"$FLAKE\"; in $1" 2>"${SMOKE_ERR:-/dev/null}"
}

# A scratch directory for tests that write files. SMOKE_TMPDIR picks where it
# goes (the default is the system temp dir); it is left in place afterwards.
scratch() {
  local base=${SMOKE_TMPDIR:-${TMPDIR:-/tmp}}
  mkdir -p "$base"
  # Physical path: a `path:` flake refuses one that runs through a symlink.
  base=$(cd "$base" && pwd -P)
  mktemp -d "$base/dotfiles-core-$1.XXXXXX"
}
