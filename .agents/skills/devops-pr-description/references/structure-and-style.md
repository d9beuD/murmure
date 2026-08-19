# PR Body Structure and Style

A pull request body has exactly four possible sections, always in this order. Omit any section that would otherwise be filler — an omitted section is more honest than an empty one.

## Context

State the problem or need that motivated this change. Give enough detail that a reviewer understands why the PR exists without having to read prior commits, chase a chat thread, or open a linked issue. One short paragraph is usually enough; if the motivation is genuinely complex it's fine to run longer, but don't pad it.

## Changes

One narrative paragraph — not a bullet list of files. Describe what was modified, added, or removed, and why it was done this way rather than some other way, when that reasoning isn't obvious from the diff itself. Name a specific file, function, or component only when it helps the reviewer navigate the diff — the goal is prose someone can read start to finish, not a change log.

Good (narrative, situates the decision):

> The export route previously loaded every record into memory before streaming the CSV, which timed out on large datasets. It now streams rows directly from the database cursor, and archived records are excluded by default since the export is meant for the active pipeline.

Avoid (mechanical file list — that belongs in the diff viewer, not the body):

> - Modified export.ts
> - Added ExportService.ts
> - Updated ExportButton.tsx

## Testing

Show the real, runnable command(s) used to verify the change, in a fenced code block — not a prose description of testing. If a command alone doesn't prove the fix (a UI change, a visual regression, a manual-only flow), add the manual steps or a screenshot alongside the command.

```bash
npm test src/services/ExportService.test.ts
```

If there is genuinely no command to run (e.g. a pure documentation change), say so plainly rather than inventing one: "No test command applies; verified by reading the rendered Markdown."

## Notes

Anything else a reviewer needs that doesn't belong above: known limitations, remaining TODOs, a dependency on another PR that must merge first, or a specific point you want the reviewer to weigh in on. Skip this section when there's nothing to add.

## Closing an issue

If the PR closes one or more issues, add the closing line as the very last line of the body, after every section:

```
Closes #42
```

or, for multiple issues:

```
Closes #42, #43
```

The issue tracker closes the issue automatically when the PR merges.

## Full example

```
## Context

The billing team needed a way to export active contract data without going
through the admin database console, which required elevated access they
didn't have.

## Changes

Added a CSV export endpoint that streams rows directly from the database
cursor instead of loading the full result set into memory, since the
previous in-memory approach timed out once the contracts table passed a
few hundred thousand rows. Archived contracts are excluded by default,
matching what the billing dashboard already assumes; an `include_archived`
flag is available for the rare case where they're needed.

## Testing

\`\`\`bash
npm test src/services/ContractExportService.test.ts
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/api/contracts/export?format=csv" -o contracts.csv
\`\`\`

Confirmed the CSV headers match the dashboard's expected column order and
that archived contracts are absent unless `include_archived=true` is passed.

## Notes

Number formatting uses a period as the decimal separator; a follow-up PR
will make this locale-aware once the dashboard supports it.

Closes #87
```

## Stop conditions

- At most four sections, in order: Context, Changes, Testing, Notes — none renamed, none added.
- Changes is one narrative paragraph, not a bullet list of touched files.
- Testing shows a real command in a fenced code block, or explicitly states none applies.
- No section contains generic filler ("various fixes", "see code") — it was omitted instead.
- `Closes #NNN` (if present) is the last line of the body.
