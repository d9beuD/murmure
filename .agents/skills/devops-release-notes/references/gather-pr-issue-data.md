# Gathering PR and Issue Data for a Release Note

Goal: before writing a single sentence, assemble a verified list of every merged pull request (and any issue it references) between the previous release and the new one — with real numbers, real authors, real links. Nothing in the release note may cite a PR/issue number, handle, or metric that isn't traceable to a command below.

## 0. Prerequisites

- `gh` CLI installed and authenticated: `gh auth status`. If unavailable, fall back to section 5.
- Know `OWNER/REPO` (e.g. from `git remote get-url origin`, strip to `owner/repo`).
- Know the previous tag (`PREV`) and the new tag/ref (`NEW`, often `HEAD` or the branch tip if not tagged yet).

```bash
git remote get-url origin
git tag --sort=-creatordate | head -10
gh release list --limit 10
```

## 1. List candidate PR numbers in range

Run both methods and reconcile — a squash-merged PR shows up in method A, a merge-commit PR shows up in method B, and comparing the two catches anything missed.

**A. From commit subjects (works for squash-merge repos):**

```bash
git log PREV..NEW --pretty=format:'%s' | grep -oE '\(#[0-9]+\)$'
```

**B. From the GitHub compare API (catches merge commits and raw messages):**

```bash
gh api repos/OWNER/REPO/compare/PREV...NEW --jq '.commits[].commit.message' \
  | grep -oE '#[0-9]+' | sort -u
```

**C. Cross-check with the merged-PR list directly (useful when A/B disagree):**

```bash
gh pr list --repo OWNER/REPO --state merged --limit 100 \
  --search "merged:>=$(git log -1 --format=%aI PREV | cut -d'T' -f1)" \
  --json number,title,mergedAt,author
```

Union the numbers from A/B, drop anything outside the PREV..NEW commit range, and de-duplicate.

## 2. Pull full detail for each PR number

One call per PR, asking for every field you'll need so you don't have to re-query it later:

```bash
gh pr view NUMBER --repo OWNER/REPO \
  --json number,title,author,body,url,mergedAt,labels,files,closingIssuesReferences
```

From the result:
- `title` → seed for the bold headline (rewrite as a precise past-tense/imperative clause — don't just copy a vague PR title verbatim).
- `body` → the "why"/mechanism for the explanation sentence, and the source of any benchmark table — copy numbers exactly, never round or estimate beyond what's stated.
- `author.login` → the attribution handle: `By [@login](https://github.com/login) in [#NUMBER](url).`
- `closingIssuesReferences` → issue(s) this PR closes; cite the issue instead of (or alongside) the PR when the note is really about the reported problem, e.g. `Reported in [#issue](issue-url).`
- `files` → which subsystem/directory the change lives in — used in SKILL.md step 3 to name the themed section (e.g. most files under `server/distributed/` → "Distributed Serving and Cluster Management").
- `labels` → secondary signal for theming/severity, if the repo uses them consistently.

## 3. Pull detail for issues not closed by a specific PR

Some notes cite an issue directly ("Reported in #NNNN") when the fix landed without an auto-linking PR, or when crediting the original report separately from the fix:

```bash
gh issue view NUMBER --repo OWNER/REPO --json number,title,body,url,author
```

Use the issue's own wording to accurately describe the symptom that was fixed.

## 4. Decide attribution style per change

- External or named contributor with a clear PR → `By [@login](profile-url) in [#NUM](pr-url).` (add a second `in [#NUM2](url)` if a follow-up PR extended the same change).
- Fix reported by one person, implemented in a PR credited to someone else (or to no one specifically) → `Reported in [#issue](url).`, optionally plus `addressing [#issue](url)` if that phrasing fits the sentence better.
- Small/rolled-up fix with no individual worth naming (e.g. inside a hotfix-history rollup section) → a bare parenthetical at the end of the bullet: `([#NUM](issue-or-pr-url))`.
- Never write "by an unknown contributor" or similar filler — if `author.login` is empty or a bot, drop the "By ..." clause entirely rather than inventing one.

## 5. Fallback when `gh` is unavailable

- `git log PREV..NEW --merges --pretty=format:'%h %s'` still gives merge-commit PR numbers and subjects.
- The GitHub REST API works with plain `curl` and a token if `gh` isn't installed: `curl -s -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" https://api.github.com/repos/OWNER/REPO/pulls/NUMBER`.
- Without any API access, you only have commit messages and diffs (`git log --grep`, `git diff PREV..NEW -- path`) — state this limitation in the draft rather than fabricating an author, PR description, or metric.

## Stop conditions for this file

- Every PR number that will appear in the release note has been fetched with `gh pr view` (or the section 5 fallback) at least once — not guessed from a commit subject alone.
- Every performance figure quoted in the draft appears verbatim in a fetched PR body or issue body.
- Every contributor handle quoted has been confirmed via `author.login`, not assumed from a commit's `Author:` line (which can differ from the GitHub handle).
