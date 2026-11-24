# Skill review: modular-skills

- Source: `github:modular/skills/d6000ab8766edeffc273b2d73efe7701397ecd8b`
- narHash: `sha256-vrGczCYr/v0XdcYcJweV+Cp19CjPyBUGjuOrNIHtkD8=`
- Skills: benchmark-model debug-model eval-model import-model migrate-max-v2-to-v3 mojo-gpu-fundamentals mojo-python-interop mojo-syntax new-modular-project profile-model serve-model
- Reviewed: 2026-11-14T14:34Z by claude --safe-mode (opus)
- Scope: diff since a98d742c7a2a
- Scan leads: 56
- Verdict: **pass**

The change since approved revision a98d742c only touches documentation in two files: mojo-syntax/SKILL.md and mojo-syntax/references/idiomatic-mojo.md. It rewrites the guidance on unwrapping Mojo `Optional` values to recommend `__guard case ... else: <exit>` and updates the related WRONG/CORRECT examples. No scripts, manifests, hooks, settings, network calls or new instructions to the agent were added. The changed files contain no hidden Unicode (zero-width, bidi or tag characters) and no encoded payloads. Every hit in scan.txt is in a file this diff doesn't touch, and each has an ordinary explanation (see findings).

| Severity | Category | Location | Detail |
|---|---|---|---|
| info | diff content | `mojo-syntax/SKILL.md:660-685; mojo-syntax/references/idiomatic-mojo.md:505-635` | The only change is a syntax-guidance update about Mojo Optional unwrapping, recommending `__guard case`. It is purely instructional Mojo code examples, with no agent-manipulation or out-of-scope instructions. |
| info | html comment (scan: injection) | `mojo-syntax/SKILL.md:6-18 (also mojo-gpu-fundamentals/SKILL.md:6, mojo-python-interop/SKILL.md:6)` | The 'EDITORIAL GUIDELINES' HTML comment is advice to human editors about keeping the file terse. It contains no hidden directives. It was already in the approved revision and is unchanged. |
| info | broad trigger | `mojo-syntax/SKILL.md:3` | The description says to 'Always use this skill when writing any Mojo code'. That is broad but stays within the skill's stated domain. It is unchanged. |
| info | network / credentials (scan) | `eval-model/scripts/eval_dataset.py:170-182, eval-model/scripts/_eval_tasks.py:331-338, import-model/scripts/compare_layers.py:202-207, run_oss_gates.py` | These scripts use urllib to call a user-supplied OpenAI-compatible model endpoint, optionally sending OPENAI_API_KEY. That matches the skills' stated purpose (evaluating and validating models). The files are unchanged from the approved revision. |
| info | bind-all (scan) | `serve-model/SKILL.md:206,271; profile-model/references/nsys.md:103` | These lines document that the MAX server's default output shows it listening on 0.0.0.0:8000. This is reference text about the user's own model server, not something the skill starts on its own. Unchanged. |
| info | dynamic-exec / subprocess (scan) | `import-model/scripts/test_scripts.py:706,894; scaffold.py:148; eval_dataset.py:600; profile-model/scripts/gpu_snapshot.py:129` | The `exec(compile(...))` calls in test_scripts.py run generated template sources as part of tests. The subprocess calls run local tooling or a user-given command. The `.eval()` hits are PyTorch model.eval(), not code execution. All unchanged. |
| info | sudo package install (scan: persistence) | `new-modular-project/SKILL.md:44-45; profile-model/SKILL.md:171; profile-model/references/nsys.md:10` | These are documented prerequisite installs (gcc, nsight-systems) through system package managers, which is normal setup guidance. None of them creates persistence. Unchanged. |
