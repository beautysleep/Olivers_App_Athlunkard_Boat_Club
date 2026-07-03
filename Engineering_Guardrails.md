# Engineering Guardrails

## Purpose

Guardrails exist to prevent coding agents from creating polished scrap: code that appears correct but violates the project control plan.

## Red lines

The agent must not:

- fabricate test data and present it as real
- hide uncertainty
- silently widen scope
- commit secrets
- change schemas without explicit approval
- change CI/CD gates without explicit approval
- use production BigQuery resources for exploratory work unless asked
- delete tests to make failures disappear
- introduce a dependency for a problem solvable with the standard library or existing stack

## Required evidence before completion

Every completed task must include:

- changed files
- tests run and result
- assumptions made
- remaining risks
- whether the change is structural, behavioural, or both

## Structural versus behavioural change

Structural change means changing shape without changing behaviour:

- rename
- move
- extract method
- simplify duplicated code
- reorganise imports

Behavioural change means user-visible or data-visible functionality changed:

- new transform logic
- new schema field
- changed mapping
- changed filtering
- changed SQL output

Do structural changes first, then behavioural changes. Never blur the two in the same proposed commit.

## Test-first rule

When changing behaviour:

1. Write or identify a failing test.
2. Make it pass with minimum code.
3. Refactor only after green.
4. Run tests again.

## Comment and print policy

- Remove temporary prints.
- Remove comments that merely narrate code.
- Keep comments only when they explain non-obvious business logic, source-system weirdness, or operational rationale.
- If code needs many comments to be understood, refactor instead.

## Secrets policy

If the agent sees a secret:

1. Stop editing.
2. Do not print the secret.
3. Report the filepath and secret type only.
4. Recommend rotation/revocation.
5. Recommend history purge if committed.

## Dependency policy

Before adding a dependency, justify:

- why existing code/standard library is not enough
- licence suitability
- operational impact in CI/CD
- test strategy

Default answer should be no.
