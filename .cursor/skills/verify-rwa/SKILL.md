---
name: verify-rwa
description: "Drive the Cypress Real World App local sign-in UI (localhost:3000) and Express API (localhost:3001) with the repo's Cypress harness. Use for /verify-rwa, or when a change needs proof of sign-in, bank accounts, payments, notifications, or user settings."
---

# Verify the Cypress Real World App

The primary surface is the React web UI. The Express API on port 3001 is the backing service the UI calls. Local username and password auth is the mode this skill drives. Auth0, Okta, Cognito, and Google are separate `yarn dev:*` modes and are out of scope.

Ports are fixed by `.env` (`PORT=3000`, `VITE_BACKEND_PORT=3001`) and by `cypress.config.ts` (`baseUrl`, `expose.apiUrl`). Two instances cannot run side by side. If 3000 or 3001 is already taken, do not start another server and do not edit those ports.

Vite listens on `::1:3000` only. Every URL in this skill uses `http://localhost`. Do not substitute `127.0.0.1`.

## Launch

From the repo root, with the toolchain below. `yarn dev` runs `predev`, which copies `data/database-seed.json` onto `data/database.json` before the servers listen. That is the seed. There is no separate migration. Do not use `yarn start:empty` for this skill; the empty seed has no users and invalid-password checks cannot find one.

Toolchain, every shell:

```shell
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
. "$NVM_DIR/nvm.sh"
nvm install 22.20.0
nvm use 22.20.0
export PATH="$NVM_DIR/versions/node/v22.20.0/bin:$PATH"
hash -r
node -v
command -v node
npm install -g yarn@1
yarn --version
```

`node -v` must print `v22.20.0` and `command -v node` must be the `v22.20.0` bin. The image Node `v22.23.4` shadows nvm if you skip the `PATH` prepend. `yarn --version` must be `1.x` (this repo pins Yarn Classic `1.22.22`). Yarn Modern will not work.

Install dependencies once, without changing versions, when `node_modules` is absent:

```shell
yarn install
```

Start the app and wait until it is usable:

```shell
.cursor/skills/verify-rwa/helpers/launch.sh
```

Ready means all of the following, which `launch.sh` waits up to 120 seconds for:

- The log contains `Backend server running at http://localhost:3001`.
- The log does not contain `Failed to start the backend server` (that line means the API moved off 3001 and Cypress will miss it).
- The log contains `http://localhost:3000`.
- `curl -sf http://localhost:3001/` prints `Cypress Realworld App - backend`.
- `curl -sf http://localhost:3000/` returns HTML containing `id="root"`.
- `curl -sf -o /dev/null http://localhost:3000/src/index.tsx` succeeds, so Vite is transforming the app and not only holding the port.

`launch.sh` writes `/tmp/verify-rwa/pid`, `/tmp/verify-rwa/yarn-dev.log`, and `/tmp/verify-rwa/meta.env`. It refuses to start when those ports are taken or when a previous verify-rwa pid is still alive. Seeded users use password `s3cret` (`SEED_DEFAULT_USER_PASSWORD` in `.env`).

`yarn dev` rewrites `data/database.json`. That diff is often only a trailing newline, and Cypress `db:seed` rewrites it again. Do not commit it. Cleanup restores the file when this run changed it.

## Doctor

Run this before every drive, and whenever the app looks wrong. It is read-only.

```shell
.cursor/skills/verify-rwa/helpers/doctor.sh
```

Exit 0 prints `DOCTOR OK`. Any miss prints `DOCTOR FAIL` and exits non-zero. It checks:

- `/tmp/verify-rwa/pid` is alive, its cwd is this checkout, its stdout is `/tmp/verify-rwa/yarn-dev.log`, and its command line is the `yarn dev` this run started.
- Ports 3000 and 3001 are listened on by that pid or one of its descendants. The helpers read `LISTEN` rows in `/proc/net/tcp` and `/proc/net/tcp6` and match the socket inode to a process fd. `ss` is not required. A foreign listener fails the doctor. Do not drive it.
- The backend child is `backend/app.ts` with `NODE_ENV=development` and without `VITE_AUTH0`, `VITE_OKTA`, `VITE_AWS_COGNITO`, or `VITE_GOOGLE`.
- `http://localhost:3000/` and `http://localhost:3001/` match the launch checks, including the exact port 3001 ready line.
- `GET http://localhost:3001/testData/users` returns seeded usernames. That endpoint exists only in development and test. It is a doctor read, not the sign-in proof.

Node reported by doctor must be `v22.20.0` from the prepended bin. Yarn must be `1.x`.

## Drive

Use the Cypress harness already in this repo: `cy.login`, `cy.getBySel`, `cy.getBySelLike`, `cy.database`, and `cy.task("db:seed")` from `cypress/support/commands.ts`. `cy.getBySel("signin-username")` is `[data-test=signin-username]`.

`cy.login(username, password)` is the user path. It opens `/signin` when needed, types `[data-test=signin-username]` and `[data-test=signin-password]`, optionally checks `[data-test=signin-remember-me]`, clicks `[data-test=signin-submit]`, and waits for `POST /login`. Do not prove the sign-in form with `cy.loginByApi` or `cy.loginByXstate`. Those skip the form. `cy.loginByXstate` is what the other UI specs use after they are already past sign-in.

The maintained auth assertions live in `cypress/tests/ui/auth.spec.ts`. The handover proof replays the two invalid-credential tests in `.cursor/skills/verify-rwa/helpers/invalid-credentials.cy.ts` and adds `cy.screenshot`. The `have.text` value stays `Username or password is invalid`. Do not weaken it. `cy.visualSnapshot` in the original spec calls Percy and does not write a PNG in this checkout.

Handover drive, one feature, invalid credentials only:

```shell
.cursor/skills/verify-rwa/helpers/drive-invalid-credentials.sh
```

That script requires a passing doctor, then runs `yarn cypress:run` (so `precypress:run` waits on `http://localhost:3000` and `http://localhost:3001`) with `--spec .cursor/skills/verify-rwa/helpers/invalid-credentials.cy.ts`. Cypress will not load that file unless `e2e.specPattern` also matches it. The default pattern is `cypress/tests/**/*.spec.ts`. The drive script passes a CLI `--config` override for that one invocation:

```shell
yarn cypress:run --spec .cursor/skills/verify-rwa/helpers/invalid-credentials.cy.ts --config '{"e2e":{"specPattern":".cursor/skills/verify-rwa/helpers/invalid-credentials.cy.ts"},"video":true,"screenshotsFolder":"/tmp/verify-rwa/artifacts/screenshots","videosFolder":"/tmp/verify-rwa/artifacts/videos","trashAssetsBeforeRuns":false}'
```

Do not edit `cypress.config.ts` to make the helper match. Cypress also prints that `experimentalStudio` was removed. Leave that option in place. The warning does not fail the run.

`yarn cypress:run` also runs `precypress:run`, which waits on `http://localhost:3000` and `http://localhost:3001`. Artifacts go to `/tmp` during the run so Vite's watcher does not reload the app while Cypress is driving it. The script copies the PNGs into the evidence directory when Cypress exits 0.

What those two tests do:

- `auth-invalid-user`: `cy.login("invalidUserName", "invalidPa$$word")`. `[data-test=signin-error]` is visible and its text is `Username or password is invalid`. The path stays `/signin`. No `connect.sid` cookie.
- `auth-invalid-password`: `cy.database("find", "users")` picks a seeded user, then `cy.login(username, "INVALID")`. The same alert, path, and cookie checks.

Both passwords are at least 4 characters, so the client schema lets the submit through and the UI shows the server failure. A shorter password never reaches that alert. See the authentication feature file for the field-error journey.

Other mapped features are driven later with their own spec, still against this same instance:

```shell
yarn cypress:run --spec cypress/tests/ui/auth.spec.ts
yarn cypress:run --spec cypress/tests/ui/bankaccounts.spec.ts
yarn cypress:run --spec cypress/tests/ui/new-transaction.spec.ts
yarn cypress:run --spec cypress/tests/ui/notifications.spec.ts
yarn cypress:run --spec cypress/tests/ui/user-settings.spec.ts
```

A passing invalid-credential run does not verify those specs. Read `features/README.md` before driving anything else. Desktop viewport is 1280x1000 (`cypress.config.ts`). Below width 414 the sidenav is behind `[data-test=sidenav-toggle]`.

## Evidence

Proof files live in `.cursor/skills/verify-rwa/evidence/`. Cleanup must not delete that directory.

| File | What it is |
| --- | --- |
| `commands.txt` | Cypress command line, exit code, Node path, Yarn version, spec, sub-features |
| `doctor.txt` | Doctor stdout from the drive |
| `cypress-invalid-credentials.log` | Full Cypress stdout and stderr |
| `auth-invalid-user.png` | Screen after the unknown-user alert assertion |
| `auth-invalid-password.png` | Screen after the wrong-password alert assertion |
| `invalid-credentials.mp4` | Cypress video of that run, when Cypress wrote one |
| `yarn-dev.log` | `yarn dev` log, copied at cleanup |

Standards:

- Drive the sign-in form with `cy.login`. Do not POST `/login` yourself and call that the UI proof. Do not call `win.authService.send("LOGIN")`.
- Capture the action and the result. The screenshot is taken after the alert assertion, while the path is still `/signin`.
- Side effects for a failed sign-in: the alert text, the URL staying `/signin`, and no `connect.sid` cookie (`saveUninitialized` is false). A 401 body is not the sentence on the alert. The alert text is `Username or password is invalid`.
- `POST /testData/seed` is the harness reset the existing specs already use (`cy.task("db:seed")`). It is allowed before the journey. It is not the journey.
- No third-party auth mock. Local passport is the real path.
- Record which sub-feature produced each artifact. Do not mark `auth-signup-onboarding-logout` verified because invalid credentials passed.
- `data/database.json` is rewritten by seed and is not evidence. Do not commit it.

## Cleanup

Stop only the process group `launch.sh` started.

```shell
.cursor/skills/verify-rwa/helpers/cleanup.sh
```

The script reads `/tmp/verify-rwa/pid`, copies the dev log into the evidence directory, sends `SIGTERM` to that process group, then `SIGKILL` to any pid from that tree that is still alive. It does not `pkill` by name and it does not kill a listener that was not in the tree. It then deletes `/tmp/verify-rwa` and, when `data/database.json` changed during the run, restores it with `git checkout -- data/database.json`.

After cleanup, confirm:

- `evidence/auth-invalid-user.png` and `evidence/auth-invalid-password.png` still exist.
- `evidence/commands.txt` still shows the Cypress exit code.
- Ports 3000 and 3001 are free, or are held by a pid the script reported it did not start.

If a drive fails halfway, run cleanup before the next launch so the ports are not stranded.

## Helpers

| Script | Invocation |
| --- | --- |
| `helpers/lib.sh` | Sourced by the other scripts. Not run directly. |
| `helpers/launch.sh` | `.cursor/skills/verify-rwa/helpers/launch.sh` |
| `helpers/doctor.sh` | `.cursor/skills/verify-rwa/helpers/doctor.sh` |
| `helpers/drive-invalid-credentials.sh` | `.cursor/skills/verify-rwa/helpers/drive-invalid-credentials.sh` |
| `helpers/cleanup.sh` | `.cursor/skills/verify-rwa/helpers/cleanup.sh` |
| `helpers/invalid-credentials.cy.ts` | Passed to `yarn cypress:run --spec` by the drive script. |

The feature map is `features/README.md`.

When the app changes, run `/maintain-verification-skill` so the map stays aligned with the UI and the specs. That pass is the upkeep loop for this skill.
