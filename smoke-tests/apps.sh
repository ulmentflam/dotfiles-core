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
bash apps/skills-review --help | grep -q 'skills-review' || fail "skills-review --help prints no usage"
echo "ok: apps, devShells and formatter resolve on all three systems"
