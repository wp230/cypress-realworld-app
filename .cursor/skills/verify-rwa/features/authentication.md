# Authentication

Authentication lets a visitor sign in, sign up, see why a form or a password was rejected, and sign out. Seeded users already exist. A new visitor can create an account and finish onboarding.

## Sub-features

- `auth-redirect-unauthenticated` sends a logged-out visit to `/personal` back to `/signin`.
- `auth-login-home` signs in a seeded user with Remember me and lands on `/`.
- `auth-remember-30-days` stores an expiring `connect.sid` cookie, then signs out to `/signin`.
- `auth-signup-onboarding-logout` creates an account, adds a bank account in onboarding, shows the transaction list, and signs out.
- `auth-login-field-errors` shows the username and password hints and keeps Sign In disabled.
- `auth-signup-field-errors` shows the sign-up hints, including a mismatched confirmation, and keeps Sign Up disabled.
- `auth-invalid-user` submits an unknown username and shows the invalid-credentials alert.
- `auth-invalid-password` submits a seeded username with the wrong password and shows the same alert.

## How to get to it (user POV)

- Open `http://localhost:3000/`. A logged-out visitor gets the Sign in page.
- Open `http://localhost:3000/signin`.
- Open `http://localhost:3000/signup`, or from Sign in choose `Don't have an account? Sign Up` (`[data-test=signup]`).
- Open a private page such as `http://localhost:3000/personal` while logged out. The app returns to `/signin`.
- After a successful sign-in, choose Logout in the sidenav (`[data-test=sidenav-signout]`). On a narrow viewport, open the drawer with `[data-test=sidenav-toggle]` first.

## Driving it with Cypress

Preconditions:

- Doctor reports this run's instance at `http://localhost:3000` and `http://localhost:3001`.
- `cy.task("db:seed")` has reloaded `data/database-seed.json`. The original spec does this in `beforeEach`.
- Desktop viewport 1280x1000 unless the step says mobile.
- Invalid-credential passwords are `invalidPa$$word` and `INVALID`, not `s3cret`.

The assertions below are the ones in `cypress/tests/ui/auth.spec.ts`. The handover script runs only `auth-invalid-user` and `auth-invalid-password`, via `helpers/invalid-credentials.cy.ts`, and takes a screenshot after the alert check. Run the rest with:

```shell
yarn cypress:run --spec cypress/tests/ui/auth.spec.ts
```

- **Redirect.** Visit `/personal`. Run `cy.visit("/personal")`. `cy.location("pathname")` equals `/signin`.
- **Login home.** Sign in the first seeded user and check Remember me. Run `cy.database("find", "users")`, then `cy.login(user.username, "s3cret", { rememberUser: true })`. The path equals `/`.
- **Remember and sign out.** Sign in the same way. `cy.getCookie("connect.sid")` has an `expiry`. Click `[data-test=sidenav-signout]` (after `[data-test=sidenav-toggle]` when the viewport is mobile). The path equals `/signin`.
- **Sign up.** Visit `/`. Click `[data-test=signup]`. `[data-test=signup-title]` contains `Sign Up`. Type `[data-test=signup-first-name]` `Bob`, `[data-test=signup-last-name]` `Ross`, `[data-test=signup-username]` `PainterJoy90`, `[data-test=signup-password]` `s3cret`, `[data-test=signup-confirmPassword]` `s3cret`. Click `[data-test=signup-submit]` and wait for `POST /users`.
- **Onboarding.** `cy.login("PainterJoy90", "s3cret")`. `[data-test=user-onboarding-dialog]` is visible, `[data-test=list-skeleton]` does not exist, and `[data-test=nav-top-notifications-count]` exists. Click `[data-test=user-onboarding-next]`. `[data-test=user-onboarding-dialog-title]` contains `Create Bank Account`. Type bank name `The Best Bank` (`[data-test*=bankName-input]`), account `123456789` (`[data-test*=accountNumber-input]`), routing `987654321` (`[data-test*=routingNumber-input]`). Click `[data-test*=submit]`. The title contains `Finished` and `[data-test=user-onboarding-dialog-content]` contains `You're all set!`. Click `[data-test=user-onboarding-next]`. `[data-test=transaction-list]` is visible. Sign out with `[data-test=sidenav-signout]`. The path equals `/signin`.
- **Login field errors.** Visit `/`. Type `[data-test=signin-username]` `User`, clear its `input`, and blur. `#username-helper-text` contains `Username is required`. Type `[data-test=signin-password]` `abc` and blur. `#password-helper-text` contains `Password must contain at least 4 characters`. `[data-test=signin-submit]` is disabled.
- **Signup field errors.** Visit `/signup`. Clear `[data-test=signup-first-name]` after typing and blur. `#firstName-helper-text` contains `First Name is required`. The same pattern on `[data-test=signup-last-name]` shows `Last Name is required`, and on `[data-test=signup-username]` shows `Username is required`. Clear `[data-test=signup-password]` and blur. `#password-helper-text` contains `Enter your password`. Type `[data-test=signup-confirmPassword]` `DIFFERENT PASSWORD` and blur. `#confirmPassword-helper-text` contains `Password does not match`. `[data-test=signup-submit]` is disabled.
- **Unknown user.** Run `cy.login("invalidUserName", "invalidPa$$word")`. `[data-test=signin-error]` is visible and its text is `Username or password is invalid`. The path is `/signin`. Screenshot `auth-invalid-user`.
- **Wrong password.** Run `cy.database("find", "users")`, then `cy.login(user.username, "INVALID")`. The same alert text is visible. The path is `/signin`. Screenshot `auth-invalid-password`.

## Gotchas

- `cy.login` types into the Material UI field root. The field-error cases clear and blur the inner `input`, matching the spec. Do not drop the blur. The hint does not appear without it.
- Sign In stays disabled until the username is non-empty and the password is at least 4 characters. `abc` never produces the invalid-credentials alert. `INVALID` and `invalidPa$$word` do.
- The alert text is `Username or password is invalid`. The passport failure message is a different sentence and is not what the page shows. Assert the alert.
- Remember me is `[data-test=signin-remember-me]` on the checkbox. The spec checks the inner `input`.
- `[data-test*=submit]` during onboarding matches the bank-account submit control. Use it only on that step, after the create-bank-account title is visible.
- `PainterJoy90` must not already exist. `cy.task("db:seed")` in `beforeEach` puts the database back. If sign-up says the user exists, the seed did not run.
- A mobile width hides Logout until `[data-test=sidenav-toggle]` is clicked. The default Cypress width does not.
- `cy.visualSnapshot` does not write a local PNG. The handover helper calls `cy.screenshot` after the same alert assertion.
- Failed sign-in must not be "fixed" by using `s3cret`. That password is valid for every seeded user.
