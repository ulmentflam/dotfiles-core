# nbu and nbs for a standalone Home Manager flake: one whose apps include
# `build` and `build-switch` (lib.mkHomeApps), switched without sudo.
#
# Returned as zsh text for the @rebuildFunctions@ slot in init.zsh. Non-empty
# lines after the first are indented to sit level with the rest of the block.
{
  lib,
  churnyInputs,
  path,
  flakeDir,
  toolVersions,
  brewfile,
}:

let
  toolVersionsRepo = if toolVersions == null then null else dirOf toolVersions;
  text = ''
    nbu() {
        local output
        output=$(nix flake update ${churnyInputs} --flake ${flakeDir} 2>&1 | tee /dev/stderr)
        git -C ${flakeDir} add flake.lock \
          && git -C ${flakeDir} commit -m "Flake update" -m "$output" \
          && nix run ${flakeDir}#build
    }

    nbs() {
        # Fail fast. A failed switch must not be followed by the mise upgrade,
        # commit and push, which would make it look as though it landed.
        if ! nix run ${flakeDir}#build-switch; then
          echo "build-switch FAILED - stopping. Skipped: ${lib.optionalString brewfile "brew bundle, "}mise upgrade, commit, push." >&2
          return 1
        fi
    ${lib.optionalString brewfile ''

      # GUI apps from the Brewfile Home Manager writes (HOMEBREW_BUNDLE_FILE).
      # Install and upgrade only: nothing is uninstalled, so apps installed
      # by hand or by device management stay put.
      if command -v brew >/dev/null 2>&1; then
        echo "Applying the Brewfile..."
        brew bundle || echo "nbs: brew bundle failed; the Home Manager switch above still applied." >&2
      fi
    ''}
        # Upgrade mise tool versions to latest. `--bump` rewrites
        # .tool-versions once per changed tool and those writes race, so loop
        # until the file stops changing. Stop on any repeated state, not just an
        # unchanged one: a tool that fails to install makes the file oscillate.
        echo "Upgrading mise tools..."
        local _tv=~/.tool-versions _i _h _seen=""
        for _i in $(seq 1 25); do
          _h=$(shasum -a 256 "$_tv" 2>/dev/null | cut -d' ' -f1)
          case " $_seen " in
            *" $_h "*) break ;;
          esac
          _seen="$_seen $_h"
          mise upgrade --bump --jobs 1
        done
        # A failed bump can uninstall the old version without landing the new
        # one. Reinstall whatever the file pins so the environment is consistent.
        mise install
    ${lib.optionalString (toolVersionsRepo != null) ''

      if ! git -C ${toolVersionsRepo} diff --quiet -- .tool-versions 2>/dev/null; then
        echo "Committing .tool-versions update..."
        local tv_diff
        tv_diff=$(git -C ${toolVersionsRepo} diff -- .tool-versions)
        git -C ${toolVersionsRepo} commit -m "Update .tool-versions" -m "$tv_diff" -- .tool-versions
      fi
    ''}
        # Push only when the checkout has an upstream; a local-only flake is fine.
        if git -C ${path} rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
          echo "Pushing to remote..."
          git -C ${path} push
        fi
    }'';
in
lib.concatStringsSep "\n" (
  lib.imap0 (i: line: if i == 0 || line == "" then line else "      " + line) (
    lib.splitString "\n" text
  )
)
