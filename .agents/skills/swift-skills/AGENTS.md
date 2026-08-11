# AGENTS.md

## Scope
- This repo is a Swift 6.3 language skill pack, not an application.
- Keep changes aligned with the official Swift documentation (swift.org) and the existing skill router style.

## Repo layout
- `skills/<skill-name>/SKILL.md` is the router file for each skill.
- `skills/<skill-name>/references/*.md` holds the detailed, on-demand docs.
- Keep `SKILL.md` short and deterministic; put examples and detail in `references/`.

## What to preserve
- Target Swift 6.3 / Swift 6 language mode (strict concurrency by default).
- Keep router instructions numbered, imperative, and anti-loop focused.
- Do not add extra abstractions, heuristics, or speculative guidance.
- Prefer exact Swift API names and verified examples over generic advice.

## Editing rules
- When updating a skill, fix the router and the matching reference together if needed.
- Do not open or rewrite every reference file for a small change; touch only the relevant ones.
- If Swift evolves past 6.3, update the version references in README.md and each SKILL.md consistently.

## Verification
- Check that any new or edited skill still points to exactly one relevant reference per task path.
- Keep the README and skill descriptions consistent with the actual file layout and supported Swift version.
