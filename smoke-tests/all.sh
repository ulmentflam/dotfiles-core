#!/usr/bin/env bash
# Run every smoke test and print a summary. All are eval-only except
# git-hooks.sh, which runs the hook against a throwaway repository, and
# about.sh and nb.sh, which run the rendered `about` and `nb` in zsh.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

TESTS=(home about nb darwin-apps ai-local-docs ai-skills git-hooks apps template no-personal)
failed=()
for t in "${TESTS[@]}"; do
  echo "==> [$t]"
  if bash "smoke-tests/$t.sh"; then
    echo "[PASS] $t"
  else
    echo "[FAIL] $t"
    failed+=("$t")
  fi
  echo
done
if [[ ${#failed[@]} -gt 0 ]]; then
  echo "${#failed[@]} failed: ${failed[*]}"
  exit 1
fi
echo "all ${#TESTS[@]} passed"
