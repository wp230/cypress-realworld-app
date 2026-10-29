# User settings

User settings lets a signed-in user open their profile form, see why a field was rejected, and save a new name, email, and phone number.

## Sub-features

- `settings-render` shows the form at `/user/settings`.
- `settings-errors` shows required and format hints and keeps Save disabled.
- `settings-save` saves a new first name and shows it in the sidenav.

## How to get to it (user POV)

- Sign in, then choose My Account in the sidenav (`[data-test=sidenav-user-settings]`). On a narrow viewport, open the drawer with `[data-test=sidenav-toggle]` first.
- Open `http://localhost:3000/user/settings` while signed in.

## Driving it with Cypress

Preconditions:

- Doctor reports this run's instance.
- `cy.task("db:seed")` has run, as in `cypress/tests/ui/user-settings.spec.ts`.
- The spec signs in with `cy.loginByXstate` on the first seeded user, then clicks `[data-test=sidenav-user-settings]`.

Run the maintained assertions with:

```shell
yarn cypress:run --spec cypress/tests/ui/user-settings.spec.ts
```

- **Render.** `[data-test=user-settings-form]` is visible. The path includes `/user/settings`.
- **Errors.** Type `Abc` into `[data-test*=firstName-input]`, clear it, and blur. `#user-settings-firstName-input-helper-text` contains `Enter a first name`. The same steps on `[data-test*=lastName-input]` show `Enter a last name`. Clear `[data-test*=email-input]` and blur. `#user-settings-email-input-helper-text` contains `Enter an email address`. Type `abc@bob.` and blur. It contains `Must contain a valid email address`. Clear `[data-test*=phoneNumber-input]` and blur. `#user-settings-phoneNumber-input-helper-text` contains `Enter a phone number`. Type `615-555-` and blur. It contains `Phone number is not valid`. `[data-test*=submit]` is disabled.
- **Save.** Clear and type `[data-test*=firstName]` `New First Name`, `[data-test*=lastName]` `New Last Name`, `[data-test*=email]` `email@email.com`, and `[data-test*=phoneNumber-input]` `6155551212`, then blur the phone field. `[data-test*=submit]` (`[data-test=user-settings-submit]`) is enabled. Click it. The `PATCH /users/*` response status is 204. `[data-test=sidenav-user-full-name]` contains `New First Name`.

## Gotchas

- The `data-test` values for the inputs live on the inner input: `user-settings-firstName-input`, `user-settings-lastName-input`, `user-settings-email-input`, `user-settings-phoneNumber-input`. The spec's `getBySelLike("firstName")` still matches. Helper ids are `#user-settings-<field>-input-helper-text`.
- Save stays disabled until the phone field has been blurred with a valid number. The spec types `6155551212` and blurs before it clicks.
- The sidenav name check is the proof that the save was visible, not only that PATCH returned 204. On a mobile width, open `[data-test=sidenav-toggle]` before reading `[data-test=sidenav-user-full-name]`.
- This journey changes the seeded user's name in `data/database.json`. The next case in the same spec relies on `db:seed` in `beforeEach`. Cleanup restores `data/database.json` and that file is not evidence.
