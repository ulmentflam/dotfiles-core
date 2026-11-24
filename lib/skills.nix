# Every skill installed into the AI tools, as { <name> = <directory>; }.
#
# Local skills come from the directories in `locals`. Third-party ones come
# from the flake inputs registered in modules/skills/sources.nix, and only at a
# revision an agent has reviewed: modules/skills/reviews.json records the
# narHash each review approved, and a lock that pins anything else fails
# evaluation here rather than linking content nobody has read.
# `nix run .#skills-review` performs and records the review.
#
# A skill is any directory holding a SKILL.md, so a skill added to a source
# needs no edit here. Names must be unique across every source, because each
# tool keys skills by directory name.
#
# A consumer flake adds its own local skills through `locals`; the defaults
# are this flake's reviewed sources and its own skills/ directory. The smoke
# tests pass fixtures for every argument.
{
  inputs,
  sources ? import ../modules/skills/sources.nix,
  reviews ? builtins.fromJSON (builtins.readFile ../modules/skills/reviews.json),
  locals ? [ ../skills ],
  reviewHint ? "nix run .#skills-review -- <name>, from the checkout that owns modules/skills/sources.nix",
}:
let

  discover =
    root: exclude:
    let
      entries = builtins.readDir root;
    in
    builtins.filter (
      name:
      entries.${name} == "directory"
      && builtins.pathExists (root + "/${name}/SKILL.md")
      && !(builtins.elem name exclude)
    ) (builtins.attrNames entries);

  fromRoot =
    root: exclude:
    map (name: {
      inherit name;
      value = root + "/${name}";
    }) (discover root exclude);

  reviewed =
    name: spec:
    let
      input =
        inputs.${name}
          or (throw "modules/skills/sources.nix lists `${name}`, but the flake has no such input.");
      review = reviews.${name} or null;
      approved = review != null && review.verdict == "pass" && review.narHash == input.narHash;
    in
    if approved then
      fromRoot (input + "/${spec.dir}") (spec.exclude or [ ])
    else
      throw ''
        Skill source `${name}` is locked at ${input.rev or "?"} (${input.narHash}), which no review has approved.
        Review it before it can be installed:
          ${builtins.replaceStrings [ "<name>" ] [ name ] reviewHint}
        To stay on the approved revision instead, restore that input's node in flake.lock.'';

  all =
    builtins.concatMap (root: fromRoot root [ ]) locals
    ++ builtins.concatLists (builtins.attrValues (builtins.mapAttrs reviewed sources));
  names = map (skill: skill.name) all;
  duplicates = builtins.attrNames (
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = null;
      }) (builtins.filter (name: builtins.length (builtins.filter (n: n == name) names) > 1) names)
    )
  );
in
if duplicates == [ ] then
  builtins.listToAttrs all
else
  throw "Two skill sources ship skills with the same name: ${toString duplicates}. Add one side to `exclude` in modules/skills/sources.nix, or rename the local skill."
