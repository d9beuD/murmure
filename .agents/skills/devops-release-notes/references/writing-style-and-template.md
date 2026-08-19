# Writing Style and Template

This is the voice and structure to match — distilled from the public release notes of [jundot/omlx](https://github.com/jundot/omlx), studied as a style reference only. Every example below is fictional/genericized; no text is reproduced from that project.

## Voice

- Factual and technical, never promotional. No emoji, no exclamation marks, no adjectives like "game-changing", "massive", "blazing fast".
- Precise: exact component/API/model names in backticks (`thinking_budget`, `<tool_result>`), exact version numbers, exact hardware (e.g. "M3 Ultra", "128 GiB Macs").
- Concrete over vague: if a measured number is available, use it ("+18.9% throughput at 32K context"); never a vague claim ("much faster") when a real figure exists. If no number is available, describe the mechanism instead of implying a magnitude.
- Honest about cost/risk: opt-in or experimental features get their tradeoffs stated plainly (e.g. "increased peak memory by about 4.15 GB and model loading time from 3.35s to ~27-29s"), not hidden.
- Candid when things went wrong: a run of rapid hotfixes gets a short, direct root-cause explanation and an acknowledgment of the disruption — not silence, not over-apologizing.

## Section order

1. **(Optional) hotfix-history blockquote** — only when this release rolls up several rapid patches. Format:

   ```
   > **Hotfix history since X.Y.0**
   >
   > - **X.Y.1:** <one-line summary of what it fixed>
   > - **X.Y.2:** <one-line summary of what it fixed>
   >
   > Sorry for the unusually frequent hotfix releases since X.Y.0. <One or two honest sentences on the root cause.> Thank you for your patience while this was resolved.
   ```

2. **Opening paragraph** — 1–3 plain sentences: what this release does, in the same technical register as the rest of the note. State the recommended upgrade path if relevant: "Users upgrading from X can move directly to Y."

3. **Themed sections (`##`)** — one per subsystem/feature area actually touched, named concretely (e.g. "Qwen3.8 VLM and Model Loading", "Distributed Serving and Cluster Management", "MCP, Memory, and Admin Fixes"). Never use bare "Features" / "Bug Fixes" as a section name — name the area, not the change type. A section can mix a feature and its related fixes if they touch the same subsystem.

   Each bullet:

   ```
   - **<Bold, precise, past-tense/imperative headline of exactly what changed>.** <One explanation sentence: mechanism, scope, or why it matters.> <Attribution — see gather-pr-issue-data.md section 4.>
   ```

   Example (genericized, not from any real project):

   ```
   - **Fixed the batch scheduler double-counting retried jobs.** Retried jobs now clear their original queue slot before re-entering the pool, so throughput metrics and concurrency limits reflect actual in-flight work. By [@example-user](https://github.com/example-user) in [#431](https://github.com/example-org/example-repo/pull/431).
   ```

   Add a markdown table when there's before/after performance data:

   ```
   | Workload | Before | After  | Improvement |
   | -------- | ------ | ------ | ----------- |
   | 4K rows  | 12.3 s | 9.8 s  | +20%        |
   ```

4. **Upgrade Notes (`##`)** — short bullets or 1–2 sentence paragraphs: default state of new opt-in/experimental features, migration requirements (or an explicit "no migration required"), and any resource/latency tradeoffs. Skip this section entirely if there's genuinely nothing to say — don't pad it.

5. **Contributor acknowledgment** — one short prose paragraph (not a bullet list, not a generic auto-generated "New Contributors" list), naming specific people and what they contributed:

   ```
   Thanks to [@a](https://github.com/a), [@b](https://github.com/b), and [@c](https://github.com/c) for their contributions.
   ```

   or, when crediting is more specific:

   ```
   Thank you to [@a](https://github.com/a) for the <specific fix> and to [@b](https://github.com/b) for the <specific fixes> included in this release.
   ```

6. **Full Changelog** — always the last line:

   ```
   **Full Changelog**: [vPREV...vNEW](https://github.com/OWNER/REPO/compare/vPREV...vNEW)
   ```

## Before / after

Bad (vague, promotional, unsourced):
> This release makes everything way faster and fixes a bunch of annoying bugs. Huge thanks to everyone involved! 🎉

Good (matches the target style):
> This release speeds up prefill by 18.9% at 32K context on M3 Ultra and fixes three cache-correctness regressions reported after the last release. Users upgrading from 0.6.0 can move directly to 0.6.1.

## Stop conditions for this file

- Every section name describes a subsystem/feature area, not a change type.
- Every bullet has exactly one bold headline, one explanation sentence, and a real attribution (or an explicit, deliberate lack of one per gather-pr-issue-data.md section 4) — no bullet is left unsourced.
- No emoji, no marketing adjectives, no vague performance language where a real number exists.
- The draft ends with a `**Full Changelog**` line pointing at a real compare URL.
