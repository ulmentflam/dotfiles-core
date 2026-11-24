#!/usr/bin/env bash
# Every app, devShell and formatter resolves on every system.
source "$(dirname "$0")/lib.sh"

for system in aarch64-darwin x86_64-linux aarch64-linux; do
  for app in build build-switch rollback skills-review; do
    eval_raw "f.apps.$system.$app.program" >/dev/null || fail "apps.$system.$app does not resolve"
  done
  eval_raw "f.devShells.$system.default.drvPath" >/dev/null || fail "devShells.$system.default does not resolve"
  eval_raw "f.formatter.$system.drvPath" >/dev/null || fail "formatter.$system does not resolve"
done
eval_raw 'f.apps.aarch64-darwin.touchid-sudo.program' >/dev/null || fail "apps.aarch64-darwin.touchid-sudo does not resolve"
eval_raw 'if f.apps.x86_64-linux ? touchid-sudo then "yes" else "no"' | grep -qx no || fail "touchid-sudo exists on Linux"
if [[ $(uname) == Darwin ]]; then
  # Read-only: reports whether sudo_local is ours, never writes.
  rc=0
  "${NIX[@]}" run "$FLAKE#touchid-sudo" -- --check >/dev/null 2>&1 || rc=$?
  [[ $rc == 0 || $rc == 1 ]] || fail "touchid-sudo --check failed to run (rc=$rc)"
fi
bash apps/skills-review --help | grep -q 'skills-review' || fail "skills-review --help prints no usage"
echo "ok: apps, devShells and formatter resolve on all three systems"
