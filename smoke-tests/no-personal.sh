#!/usr/bin/env bash
# This repository is public: no personal identity, host, key or address may
# land in it. Scans every tracked file and the rendered placeholder config for
# the shapes personal data takes. Names and hosts that are yours alone belong in
# PERSONAL_PATTERNS (an extended regex), supplied from somewhere private, never
# written into this file.
source "$(dirname "$0")/lib.sh"

# SSH public key blobs, home directories other than the placeholders, and
# Tailscale CGNAT addresses (the 100.64/10 block).
patterns='AAAA(C3NzaC1lZDI1NTE5|B3NzaC1yc2E)[A-Za-z0-9+/]{8}|/(Users|home)/[a-z][a-z0-9._-]*|100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.[0-9]+\.[0-9]+'
allowed='/(Users|home)/(example|smokeuser|me|user|runner)\b'
[[ -n ${PERSONAL_PATTERNS:-} ]] && patterns="$patterns|$PERSONAL_PATTERNS"

hits=$(git ls-files -z | xargs -0 grep -nIoiE "$patterns" -- 2>/dev/null | grep -viE "$allowed" || true)
[[ -z $hits ]] || fail "personal data in tracked files:
$hits"

rendered=$(eval_raw '
  let c = f.homeConfigurations.aarch64-darwin.config; in
  c.programs.zsh.initContent + c.home.file."CLAUDE.local.md".text + c.home.file.".ssh/config".text
') || fail "placeholder config did not render"
bad=$(grep -oiE "$patterns" <<<"$rendered" | grep -viE "$allowed" || true)
[[ -z $bad ]] || fail "personal data in the rendered placeholder config: $bad"
echo "ok: no key blobs, personal home paths or tailnet addresses${PERSONAL_PATTERNS:+, nor PERSONAL_PATTERNS,} in tracked files or the rendered configuration"
