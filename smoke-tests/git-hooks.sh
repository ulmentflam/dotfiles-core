#!/usr/bin/env bash
# The pre-commit hook (.githooks/pre-commit) against a throwaway repo, and the
# module that installs it (modules/git-hooks.nix). Runs the hook for real;
# needs no network.
source "$(dirname "$0")/lib.sh"
HOOK="$ROOT/.githooks/pre-commit"

echo "==> 1. Hook script exists, is executable, and parses"
[[ -f "$HOOK" ]] || fail ".githooks/pre-commit missing"
[[ -x "$HOOK" ]] || fail ".githooks/pre-commit is not executable (git will ignore it)"
bash -n "$HOOK" || fail ".githooks/pre-commit has a syntax error"
echo "ok: hook present, executable, syntactically valid"

echo
echo "==> 2. Resolve the nixfmt the flake itself is wired to"
NIXFMT_BIN="$(command -v nixfmt || true)"
if [[ -z "$NIXFMT_BIN" ]]; then
  SYSTEM=$("${NIX[@]}" eval --impure --raw --expr 'builtins.currentSystem')
  NIXFMT_BIN="$("${NIX[@]}" build --no-link --print-out-paths ".#formatter.${SYSTEM}")/bin/nixfmt"
fi
[[ -x "$NIXFMT_BIN" ]] || fail "could not resolve a nixfmt binary"
echo "ok: nixfmt at $NIXFMT_BIN"

echo
echo "==> 3. Hook behavior against a throwaway repo"

TMP=$(scratch git-hooks)
printf '%s\n' 'Retained Git hook behavior fixtures. No credentials.' >"$TMP/README.txt"

git init -q "$TMP/repo"
(
  cd "$TMP/repo"
  git config user.email smoke@test.local
  git config user.name "smoke test"
  git config commit.gpgsign false
  mkdir -p .githooks
  cp "$HOOK" .githooks/pre-commit
  chmod +x .githooks/pre-commit
  # Exactly how modules/git-hooks.nix installs it.
  git config --local core.hooksPath .githooks
)

cd "$TMP/repo"
PATH="$(dirname "$NIXFMT_BIN"):$PATH"
export PATH

pass=0
tried=0
# expect <name> <expected-rc> -- runs the pending commit and compares rc
expect() {
  local name="$1" want="$2" got=0
  shift 2
  tried=$((tried + 1))
  "$@" >/dev/null 2>&1 || got=$?
  if [[ "$got" == "$want" ]]; then
    echo "  ok: $name (rc=$got)"
    pass=$((pass + 1))
  else
    echo "  FAIL: $name (expected rc=$want, got rc=$got)"
  fi
}

echo hi >README.md
git add README.md
expect "commit with no .nix files is allowed" 0 \
  git commit -m "no nix"

printf '{\n  a = 1;\n}\n' >good.nix
git add good.nix
expect "nixfmt-clean .nix is allowed" 0 \
  git commit -m "good nix"

printf '{a=1;   b   =2;}\n' >bad.nix
git add bad.nix
expect "unformatted .nix is blocked" 1 \
  git commit -m "bad nix"

# The important one: the hook reads the *staged* blob, not the worktree, so
# formatting the file without re-adding it must still fail.
"$NIXFMT_BIN" bad.nix
expect "worktree fixed but not re-staged is still blocked" 1 \
  git commit -m "fixed on disk only"

git add bad.nix
expect "formatted and re-staged is allowed" 0 \
  git commit -m "fixed and staged"

git rm -q bad.nix
expect "staged deletion of a .nix file is allowed" 0 \
  git commit -m "delete nix file"

printf '{a=1;   b   =2;}\n' >bypass.nix
git add bypass.nix
expect "--no-verify bypasses the hook" 0 \
  git commit --no-verify -m "bypass"

# A fresh clone that hasn't run nbs yet has no nixfmt. The hook must warn and
# let the commit through rather than blocking bootstrap.
printf '{a=1;   b   =2;}\n' >nofmt.nix
git add nofmt.nix
expect "missing nixfmt warns but allows" 0 \
  env PATH=/usr/bin:/bin git commit -m "no nixfmt"

[[ "$pass" -eq "$tried" ]] || fail "$((tried - pass)) of $tried hook cases failed"
echo "ok: all $tried hook cases behaved correctly"

cd "$OLDPWD"

echo
echo
echo "==> 4. The activation sets a repo-local core.hooksPath, once per checkout"
OUT=$(eval_raw '
  (f.homeConfigurations.aarch64-darwin.extendModules {
    modules = [ { dotfiles.gitHooks.repos = [ "$HOME/one" "$HOME/two" ]; } ];
  }).config.home.activation.dotfilesGitHooks.data
') || fail "home.activation.dotfilesGitHooks does not exist"
grep -q -- "config --local core.hooksPath" <<<"$OUT" || fail "activation must use git config --local"
[[ $(grep -c '^repo=' <<<"$OUT") == 2 ]] || fail "expected one block per listed checkout"
DEFAULT=$(eval_raw 'f.homeConfigurations.aarch64-darwin.config.home.activation.dotfilesGitHooks.data')
grep -qx 'repo="$HOME/dotfiles-core"' <<<"$DEFAULT" || fail "default repo is not dotfiles.repo.path with ~ as \$HOME"
echo "ok: repo-local hooksPath, one block per checkout, default from dotfiles.repo.path"
