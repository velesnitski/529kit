# ADR 0002: CI and branching model

Date: 2026-09-04
Status: accepted

## Context

v0.1 shipped as a single commit on `main`. The repo needs a working model
for changes and a check that branch protection can pin.

## Decisions

1. **Branches: `dev` → `main`.** Day-to-day work lands on `dev`; `main`
   moves by fast-forward merge once CI is green on `dev`. `main` is the
   default branch and what users clone.

2. **CI = `lint` job** (GitHub Actions, free for public repos):
   `bash -n` syntax pass, `shellcheck -S warning` on all shell scripts,
   and a cheap grep that fails the build if anything shaped like a
   hardcoded secret appears. Runs on pushes to both branches and on PRs.

3. **Branch protection on `main`** follows the solo-maintainer recipe:
   required status check `lint` (strict: false), `enforce_admins` off so a
   release fast-forward push by the owner survives, no PR-review
   requirement (there is one maintainer).

## Consequences

- A red `dev` cannot be fast-forwarded into `main` without noticing.
- The secret-shape grep is a tripwire, not a scanner — real hygiene is
  "secrets never enter the repo" (ADR 0001), this just catches accidents.
