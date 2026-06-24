# Repository Rules

This document records the intended GitHub repository rules for this project.

These rules are not enforced by this file. GitHub branch protection, rulesets,
merge settings, and Actions settings must be configured in GitHub itself.

The purpose of this file is to keep the operating model explicit so that local
development, mobile review, Copilot coding agent work, and Codex work all follow
the same control system.

## Core Principle

`main` should represent deployable truth.

Work should happen on branches. Agents and humans may open pull requests, but
code should only enter `main` after the agreed checks and review gates pass.

## Recommended GitHub Settings

### Branch Or Ruleset Target

Target branch:

```text
main
```

Preferred mechanism:

```text
GitHub ruleset, if available.
Classic branch protection is acceptable if rulesets are not available.
```

## Main Branch Rules

Recommended rules for `main`:

```text
Require a pull request before merging: yes
Required approvals: 1
Dismiss stale approvals when new commits are pushed: yes
Require review from code owners: later, once CODEOWNERS exists
Require status checks before merging: yes, once CI exists
Require branches to be up to date before merging: yes, once CI exists
Require conversation resolution before merging: yes
Restrict who can push directly: yes
Allow force pushes: no
Allow deletions: no
```

During the planning-only phase, status checks may not exist yet. Once CI is
added, the required checks should include at least:

```text
lint
typecheck
test
build
```

## Pull Request Rules

Recommended pull request settings:

```text
Default merge method: squash merge
Allow squash merge: yes
Allow merge commits: no
Allow rebase merge: optional
Automatically delete head branches: yes
Allow auto-merge: yes, after checks and review pass
```

Reasoning:

- Squash merge keeps `main` readable.
- Agent branches may contain noisy iteration commits.
- Auto-merge is useful from mobile once a PR has approval and passing checks.

## Agent Autonomy Model

Agents may:

```text
Open issues
Comment on issues
Create branches
Commit to their own branches
Open draft pull requests
Update pull requests in response to review
Run tests and checks
```

Agents may not:

```text
Push directly to main
Merge their own pull requests
Bypass failing checks
Change production infrastructure without explicit review
Change authentication, authorization, or security rules without explicit review
Make database schema changes without documenting the migration and rollback path
Silently alter repository governance settings
```

## Mobile Operating Model

Mobile should be treated as a command-and-review console, not as the primary
development environment.

Good mobile actions:

```text
Create or update issues
Assign issues to Copilot coding agent
Comment on pull requests
Review diffs for small changes
Approve low-risk pull requests
Enable auto-merge after checks pass
Merge approved, passing pull requests
```

Risky mobile actions:

```text
Review large diffs
Approve security-sensitive changes
Approve infrastructure changes
Approve database schema changes
Resolve complex merge conflicts
Make non-trivial code edits directly in the browser
```

## Risk Levels

Low-risk changes may be reviewed and approved from mobile:

```text
Documentation changes
Small UI text changes
Test-only changes
Simple configuration changes with passing checks
Small bug fixes with clear tests
```

High-risk changes should be reviewed from a proper development environment:

```text
Authentication or authorization changes
Data model or BigQuery schema changes
Cloud Run deployment changes
Cloud Storage permissions changes
Secrets or environment variable handling
Payment, billing, or user data workflows
Large refactors
Changes with weak or missing tests
```

## Future Additions

Likely future governance files:

```text
CODEOWNERS
.github/pull_request_template.md
.github/ISSUE_TEMPLATE/
.github/workflows/ci.yml
docs/decisions/
docs/architecture/
docs/product/
```

## Setup Checklist

In GitHub repository settings:

```text
1. Confirm Actions are enabled.
2. Enable only squash merge, unless there is a reason to keep another method.
3. Enable automatically delete head branches.
4. Enable auto-merge.
5. Create a ruleset or branch protection rule for main.
6. Require pull requests before merging.
7. Require 1 approval.
8. Enable stale approval dismissal.
9. Require conversation resolution.
10. Disable force pushes and branch deletion.
11. After CI exists, require lint, typecheck, test, and build checks.
```

