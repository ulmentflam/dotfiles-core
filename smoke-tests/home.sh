#!/usr/bin/env bash
# homeConfigurations for every system evaluate, enable the core programs and
# carry the placeholder identity from examples/home.nix, never a real one.
source "$(dirname "$0")/lib.sh"

for system in aarch64-darwin x86_64-linux aarch64-linux; do
  echo "==> $system"
  out=$(eval_raw "
    let
      c = f.homeConfigurations.$system.config;
      b = x: if x then \"true\" else \"false\";
    in
    \"drv=\${f.homeConfigurations.$system.activationPackage.drvPath}\\n\"
    + \"home=\${c.home.homeDirectory}\\n\"
    + \"git-user=\${c.programs.git.settings.user.name} <\${c.programs.git.settings.user.email}>\\n\"
    + \"signing=\${b (c.programs.git.signing.signByDefault == true)}\\n\"
    + \"enabled=\${b (c.programs.zsh.enable && c.programs.git.enable && c.programs.tmux.enable && c.programs.starship.enable && c.programs.mise.enable)}\\n\"
    + \"unslotted=\${b (builtins.match \".*@[a-zA-Z]+@.*\" c.programs.zsh.initContent != null)}\\n\"
    + \"brew-shellenv=\${b (builtins.match \".*brew shellenv.*\" c.programs.zsh.initContent != null)}\\n\"
  ") || fail "$system did not evaluate"
  echo "$out"
  grep -q '^drv=/nix/store/.*home-manager-generation.drv' <<<"$out" || fail "$system has no activation package"
  grep -q '^git-user=Example User <user@example.invalid>$' <<<"$out" || fail "$system git identity is not the placeholder"
  grep -q '^signing=false$' <<<"$out" || fail "$system signs commits with no key configured"
  grep -q '^enabled=true$' <<<"$out" || fail "$system is missing a core program"
  grep -q '^unslotted=false$' <<<"$out" || fail "$system left an @slot@ unfilled in the zsh init"
  grep -q '^brew-shellenv=false$' <<<"$out" || fail "$system runs brew shellenv without dotfiles.homebrew.enable"
  case $system in
    *darwin) grep -q '^home=/Users/example$' <<<"$out" || fail "darwin home directory is not /Users/<username>" ;;
    *) grep -q '^home=/home/example$' <<<"$out" || fail "linux home directory is not /home/<username>" ;;
  esac
done

echo
echo "==> options reach the rendered files"
out=$(eval_raw '
  let
    hm = f.homeConfigurations.aarch64-darwin.extendModules {
      modules = [ {
        dotfiles = {
          git.signing = { key = "ssh-ed25519 AAAAtest"; signer = "/bin/signer"; };
          ssh = {
            identityAgent = "~/agent.sock";
            hosts."git.example".IdentityFile = [ "~/.ssh/id_example.pub" ];
            publicKeys.id_example = "ssh-ed25519 AAAAtest";
          };
          homebrew.enable = true;
          toolVersions = "/Users/example/dotfiles-core/.tool-versions";
        };
      } ];
    };
    c = hm.config;
  in
  "${c.home.file.".ssh/config".text}\n"
  + "signer=${c.programs.git.signing.signer}\n"
  + "pubkey=${c.home.file.".ssh/id_example.pub".text}\n"
  + "tool-versions=${if c.home.file ? ".tool-versions" then "linked" else "missing"}\n"
  + "shellenv=${if builtins.match ".*brew shellenv.*" c.programs.zsh.initContent != null then "yes" else "no"}\n"
  + "opt-homebrew-path=${if builtins.match ".*/opt/homebrew/bin:.*" c.programs.zsh.initContent != null then "yes" else "no"}\n"
') || fail "option overrides did not evaluate"
grep -q 'IdentityAgent ~/agent.sock' <<<"$out" || fail "identityAgent missing from ssh config"
grep -q 'Host git.example' <<<"$out" || fail "ssh host block missing"
grep -q '^signer=/bin/signer$' <<<"$out" || fail "signer not applied"
grep -q '^pubkey=ssh-ed25519 AAAAtest$' <<<"$out" || fail "public key not written"
grep -q '^tool-versions=linked$' <<<"$out" || fail ".tool-versions not linked"
grep -q '^shellenv=yes$' <<<"$out" || fail "homebrew.enable does not run brew shellenv"
grep -q '^opt-homebrew-path=yes$' <<<"$out" || fail "homebrew.enable does not put /opt/homebrew/bin on PATH"
echo "ok: identity, signing, ssh, public keys, .tool-versions and Homebrew PATH all flow from options"

echo
echo "==> packages.exclude drops a package and refuses an unknown name"
out=$(eval_raw '
  let
    with_ = ex: (f.homeConfigurations.aarch64-darwin.extendModules {
      modules = [ { dotfiles.packages.exclude = ex; } ];
    }).config;
    names = c: map (p: p.pname or (f.inputs.nixpkgs.lib.getName p)) c.home.packages;
    # Home Manager raises failed assertions when the config is read.
    failed = c: !(builtins.tryEval (builtins.deepSeq (builtins.filter (a: !a.assertion) c.assertions == [ ]) true)).success
      || builtins.filter (a: !a.assertion) c.assertions != [ ];
    b = x: if x then "true" else "false";
  in
  "tor-by-default=${b (builtins.elem "tor" (names (with_ [ ])))}\n"
  + "tor-excluded=${b (!(builtins.elem "tor" (names (with_ [ "tor" ]))))}\n"
  + "jq-kept=${b (builtins.elem "jq" (names (with_ [ "tor" ])))}\n"
  + "typo-refused=${b (failed (with_ [ "not-a-package" ]))}\n"
  + "mise=${b ((with_ [ "tor" ]).programs.mise.enable && builtins.elem "mise" (names (with_ [ "tor" ])))}\n"
  + "doc-follows=${b (!(builtins.match ".*`tor` - .*" (with_ [ "tor" ]).home.file."CLAUDE.local.md".text != null))}\n"
') || fail "exclude configurations did not evaluate"
echo "$out"
grep -q '=false' <<<"$out" && fail "packages.exclude: $(grep '=false' <<<"$out" | tr '\n' ' ')"
echo "ok: exclude removes from home.packages and the AI doc; typos fail evaluation; mise stays"
