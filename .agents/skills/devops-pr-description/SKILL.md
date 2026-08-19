---
name: devops-pr-description
description: >-
  Use when writing or reviewing the body of a pull request (GitHub or
  similar), so reviewers get enough context without digging through history
  or issues. Covers a fixed four-section structure (Context, Changes,
  Testing, Notes) with concrete style rules per section — Testing always
  shows a real runnable command, Changes is a narrative paragraph rather
  than a file-by-file bullet list.
---

Write PR bodies a reviewer can act on immediately: a fixed four-section structure, no filler, no vague claims.

## Use this skill when

- Writing or updating the body of a pull request before opening or updating it.
- Deciding what belongs in a PR description versus a commit message.
- Reviewing whether an existing PR body is complete enough to merge as-is.

## Do not use this skill when

- Writing the PR title — that follows a different convention (e.g. Conventional Commits) and is out of scope here.
- Writing a commit message — use git-commit.
- Writing release notes or a CHANGELOG entry — use devops-release-notes.
- The change has no meaningful context to add (a trivial one-line typo fix) — a short body is fine; don't stretch it to fill all four sections.

## Instructions

Follow these steps in order. Do the minimum needed; stop once the body matches the checklist below.

1. Identify what actually changed: read the diff (`git diff` / `git log`) and any linked issue or discussion before writing — don't rely on memory of "what I meant to do".
2. Open `references/structure-and-style.md` and follow its four-section template: Context, Changes, Testing, Notes.
3. Write Context: the problem or need behind the change, with enough detail that a reviewer understands without digging through history or issues.
4. Write Changes as one narrative paragraph (never a bullet list of files) describing what was modified, added, or removed, plus any notable technical decision or known side effect.
5. Write Testing with the real, runnable command(s) used to verify the change, in a fenced code block, plus manual steps or a screenshot when a command alone doesn't prove it. If no command applies, say so explicitly instead of inventing one.
6. Write Notes only if there's something to say: known limitations, remaining TODOs, a dependency on another PR, or a specific point for the reviewer to weigh in on.
7. Drop any of the four sections that would otherwise contain generic filler ("various improvements", "see code") — an omitted section says more than an empty one.
8. If the PR closes one or more issues, add `Closes #NNN` (or `Closes #NNN, #NNN`) as the very last line, after every section.

Anti-loop rules:
- Four sections, fixed order, no extra named sections — don't invent a fifth section for something that fits under Notes.
- ONE narrative paragraph for Changes — never degrade into a bullet-per-file list.
- Testing must show an actual command when one exists — never replace it with "run the tests" prose.
- Stop once the four (or fewer) sections are written and any `Closes` line is added — no extra passes, no rewriting a section that already meets the checklist.

## Reference files

- `references/structure-and-style.md` — the four-section template, what belongs in each section, the style rules for Changes (narrative, not a file list) and Testing (always the real command), and a full worked example.
