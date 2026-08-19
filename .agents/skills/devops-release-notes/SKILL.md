---
name: devops-release-notes
description: >-
  Use when writing release notes, a CHANGELOG entry, or a GitHub Release body
  for a git/GitHub repo, in a factual, subsystem-grouped, precisely-attributed
  style (modeled on well-regarded open source release notes such as
  jundot/omlx). Covers gathering the underlying merged pull request and issue
  data with git/gh before drafting, not just the writing itself.
---

Write release notes that are factual, subsystem-grouped, and traceable to real merged pull requests and issues — never invented.

## Use this skill when

- Drafting the body of a new GitHub Release or a CHANGELOG entry for a tagged version.
- Summarizing what changed between two tags/refs (features, fixes, performance work) for end users or downstream integrators.
- Writing a "hotfix rollup" note that covers several rapid patch releases since the last stable tag.
- Deciding how to credit contributors and cite pull requests/issues in a release body.

## Do not use this skill when

- Writing an individual commit message — use git-commit.
- Writing a pull request title/description — use gh-pull-request.
- Writing marketing/launch copy meant to hype a release for a general audience — this style is deliberately plain and technical, not promotional.
- The repo has no PR/issue tracker to check (e.g. a solo repo with no history) — there's nothing to gather; write directly from the diff instead.

## Instructions

Follow these steps in order. Do the minimum needed; stop once the draft is fully sourced and matches the checklist.

1. Identify the version range: the previous released tag/ref and the new tag/ref (or `HEAD` if not yet tagged). Confirm both exist with `git tag --sort=-creatordate | head` or `gh release list --limit 5`.
2. Open `references/gather-pr-issue-data.md` and follow it exactly to collect every merged PR and referenced issue in range — number, title, author, body, linked issues, touched files, and any benchmark figures. Use only what `git`/`gh` return; never guess a number, handle, or metric.
3. Group the collected changes into 2–6 sections named after the actual subsystem/feature area they touch (e.g. "Distributed Serving and Cluster Management"), not generic labels like "Features" or "Bug Fixes".
4. Open `references/writing-style-and-template.md` and follow it to draft: an opening summary paragraph, the themed sections with bullets, an optional "Upgrade Notes" section, a contributor-thanks paragraph, and the closing "Full Changelog" line.
5. Write each bullet as a bold, precise headline, one explanation sentence, then the PR/issue attribution — using only facts gathered in step 2.
6. If this release rolls up prior patch/hotfix releases, add the intro blockquote from the template: list what each prior patch fixed, and explain candidly why the hotfixes were needed.
7. Re-read the draft against the checklist at the end of `references/writing-style-and-template.md` before stopping.

Anti-loop rules:
- ONE gathering pass per version range with `references/gather-pr-issue-data.md`; do not re-query the same PR/issue repeatedly.
- Never invent a PR number, issue number, contributor handle, or performance metric — if it isn't confirmed by `git`/`gh` output, omit the claim instead of guessing or approximating.
- Stop once every merged PR/issue in range is either represented in a bullet or explicitly set aside as not user-facing (pure CI/test/doc-only changes) — do not loop trying to force every commit into the note.
- Do not add emoji, marketing adjectives ("game-changing", "blazing fast"), or vague performance claims ("much faster") when a concrete measured number is available or obtainable instead.

## Reference files

- `references/gather-pr-issue-data.md` — open first, for the `git`/`gh` commands to enumerate merged PRs and issues in a version range and pull their metadata.
- `references/writing-style-and-template.md` — open second, for the section template, bullet format, tone rules, and a before/after example.
