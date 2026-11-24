# Third-party skill repositories, keyed by their flake input in flake.nix
# (declared there with `flake = false`). `dir` is where the skills sit inside
# the repository; every directory under it with a SKILL.md is installed.
# `exclude` drops individual skills by directory name.
#
# Nothing here is linked until reviews.json approves the exact content the
# lock pins. To add a repository: declare the input, add it here, then run
# `nix run .#skills-review -- <name>`. See CLAUDE.md "AI skills".
{
  # Modular's Mojo and MAX skills. Apache-2.0 with LLVM exceptions.
  modular-skills = {
    dir = ".";
  };

  # Jesse Vincent's development-methodology skills. MIT. Installed as plain
  # skills, without the plugin's SessionStart hook, so `using-superpowers` is
  # loaded on demand rather than injected into every session.
  superpowers = {
    dir = "skills";
  };
}
