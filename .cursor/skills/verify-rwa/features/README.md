# Cypress Real World App verification map

This directory is the maintained source for verifying the user-facing behavior of the Cypress Real World App. Read the index before driving the app, then use the matching feature file as the recipe.

The handover proof drives authentication's invalid-credential cases only. The other files are here so later runs can cover them. A passing invalid-credential run does not verify the other features, and one entry point does not verify the other entry points in the same file.

## Baseline preconditions

- One local instance started by `.cursor/skills/verify-rwa/helpers/launch.sh`.
- Frontend at `http://localhost:3000`. API at `http://localhost:3001`. Use `localhost`, not `127.0.0.1`.
- Node `v22.20.0` first on `PATH` (`.node-version`). Yarn Classic `1.x`.
- `yarn dev` has copied `data/database-seed.json` to `data/database.json`. Seeded users sign in with password `s3cret`.
- `.cursor/skills/verify-rwa/helpers/doctor.sh` prints `DOCTOR OK` for this run's pid, log, and ports.
- Never drive an instance that doctor does not attribute to this run.
- Do not start a second instance. Ports 3000 and 3001 are exclusive.

## Driving conventions

- Start every recipe from the baseline state unless its preconditions say otherwise.
- Prefer `[data-test=...]` handles from the feature file. The harness commands are `cy.getBySel` (exact) and `cy.getBySelLike` (substring).
- Sign-in UI proof uses `cy.login`. Bank accounts, payments, notifications, and settings specs sign in with `cy.loginByXstate` only after the auth feature has already covered the form.
- Run the existing spec when the file lists a count or copy assertion. Do not replace it with a looser check.
- Desktop viewport is 1280x1000. A mobile viewport is under 414 pixels wide and needs `[data-test=sidenav-toggle]` before sidenav items.
- Restore nothing by hand except what cleanup already does. Do not delete proof artifacts.
- Do not commit `data/database.json`.

## Proof and skip reporting

- Capture the user action and the resulting state, not only the final screen.
- UI proof for the handover run is the Cypress log, the exit code, and the screenshot taken after the alert assertion.
- Record the feature id and the entry point with every artifact.
- Report an unreachable path with the command that failed and the unmet precondition.
- Do not report a skipped entry point as verified through a different path.

## Feature entry contract

Each feature file starts with an H1 and one paragraph, then these four H2 sections in order:

1. `Sub-features`
2. `How to get to it (user POV)`
3. `Driving it with Cypress`
4. `Gotchas`

## Features

- [Authentication](./authentication.md) covers redirect, login, remember-me, sign-up and onboarding, field errors, and invalid credentials.
- [Bank accounts](./bank-accounts.md) covers create, validation, soft delete, and the empty list.
- [New transaction](./new-transaction.md) covers payment, request, validation, and the receiver's balance.
- [Notifications](./notifications.md) covers likes, comments, payments, requests, and the empty list.
- [User settings](./user-settings.md) covers the profile form, validation, and saving a name.

Transaction feeds (`cypress/tests/ui/transaction-feeds.spec.ts`) and transaction view (`cypress/tests/ui/transaction-view.spec.ts`) are user-facing and are not mapped yet. Do not treat them as covered.
