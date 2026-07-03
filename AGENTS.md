# AGENTS.md

Source of truth for repository-wide agent behaviour. Read this first.

## Non-negotiable operating rules

1. Do not invent requirements, schemas, data, credentials, Jira IDs, suppliers, or BigQuery table names.
2. Do not commit, expose, print, or create real secrets. If credentials are present in the repo, stop and raise a security warning.
3. Do not modify generated data, historical snapshots, coverage HTML, or service-account files unless explicitly asked.
4. Do not mix structural and behavioural changes in the same logical change.
5. Do not perform broad refactors while implementing a feature. Mention adjacent problems separately.
6. Do not keep debug prints or non-additive comments in finished code.
7. Do not reduce test coverage knowingly without an explicit rationale.
8. Do not make network, cloud, or BigQuery changes unless the task explicitly requires them.

## Default workflow

For every non-trivial task:

1. Inspect the relevant files first.
2. State assumptions and uncertainties briefly.
3. Write or identify the smallest failing test.
4. Implement the minimum code needed to pass.
5. Run the most relevant tests.
6. Refactor only after tests pass.
7. Run tests again after refactoring.
8. Summarise:
   - files changed
   - behavioural changes
   - structural changes
   - tests run
   - risks left

## Code style

- Prefer clear names over clever abstractions.
- Keep functions small and behaviour-focused.
- Make dependencies explicit.
- Minimise state and side effects.

## Commit discipline

Do not create commits unless explicitly asked. If asked to propose commits, separate them as:

- `STRUCTURAL: ...` for renaming, moving, extracting, or simplification with no behaviour change.
- `BEHAVIOURAL: ...` for new/changed functionality.

A logical unit of work is ready only when relevant tests pass and lint/type issues are addressed.

## When to ask before proceeding

Ask before:

- deleting files
- changing public schemas
- changing BigQuery table procedure names
- adding dependencies
- changing CI/CD behaviour
- altering credential handling
- doing broad refactors
- touching specific business logic where expected output is ambiguous
