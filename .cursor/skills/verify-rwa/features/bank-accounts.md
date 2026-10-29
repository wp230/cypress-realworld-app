# Bank accounts

Bank accounts lets a signed-in user open their account list, create an account, see why a new account form is invalid, and soft-delete an account.

## Sub-features

- `bank-create` adds an account named `The Best Bank` and shows it in the list.
- `bank-form-errors` shows bank name, routing, and account number hints and keeps submit disabled.
- `bank-soft-delete` marks the first account deleted.
- `bank-empty` shows the empty header and the onboarding dialog when the list is empty.

## How to get to it (user POV)

- Sign in, then choose Bank Accounts in the sidenav (`[data-test=sidenav-bankaccounts]`). On a narrow viewport, open the drawer with `[data-test=sidenav-toggle]` first.
- Open `http://localhost:3000/bankaccounts` while signed in.
- From the list, choose Create (`[data-test=bankaccount-new]`), which goes to `/bankaccounts/new`.

## Driving it with Cypress

Preconditions:

- Doctor reports this run's instance.
- `cy.task("db:seed")` has run, as in `cypress/tests/ui/bankaccounts.spec.ts`.
- The spec signs in with `cy.loginByXstate` on the first seeded user. That is the post-auth entry this file uses. It does not replace the authentication feature's form proof.

Run the maintained assertions with:

```shell
yarn cypress:run --spec cypress/tests/ui/bankaccounts.spec.ts
```

- **Create.** Click `[data-test=sidenav-bankaccounts]`, then `[data-test=bankaccount-new]`. The path equals `/bankaccounts/new`. Type `[data-test*=bankName-input]` `The Best Bank`, `[data-test*=routingNumber-input]` `987654321`, `[data-test*=accountNumber-input]` `123456789`. Click `[data-test*=submit]`. A `[data-test*=bankaccount-list-item]` contains `The Best Bank`. The spec expects two list items after the create.
- **Form errors.** Visit `/bankaccounts`, click `[data-test=bankaccount-new]`. Clear `[data-test*=bankName-input]` and blur. `#bankaccount-bankName-input-helper-text` contains `Enter a bank name`. Type `The` and blur. The same helper contains `Must contain at least 5 characters`. Blur an empty `[data-test*=routingNumber-input]`. `#bankaccount-routingNumber-input-helper-text` contains `Enter a valid bank routing number`. Type `12345678` and blur. It contains `Must contain a valid routing number`. Type `123456789` and blur. That helper is gone. Blur an empty `[data-test*=accountNumber-input]`. `#bankaccount-accountNumber-input-helper-text` contains `Enter a valid bank account number`. Type `12345678`. It contains `Must contain at least 9 digits`. Type `1234567891111`. It contains `Must contain no more than 12 digits`. `[data-test=bankaccount-submit]` is disabled.
- **Soft delete.** Visit `/bankaccounts`. Click the first `[data-test*=delete]`. A list item contains `Deleted`.
- **Empty list.** The spec stubs the GraphQL `ListBankAccount` result to an empty array, then visits `/bankaccounts`. `[data-test=bankaccount-list]` does not exist. `[data-test=empty-list-header]` contains `No Bank Accounts`. `[data-test=user-onboarding-dialog]` is visible. If the stub is not in place, do not claim the empty state from a seeded list.

## Gotchas

- The rendered list id is `bankaccount-list-item-<id>`. `cy.getBySelLike("bankaccount-list-item")` is the spec's handle.
- Delete is `[data-test=bankaccount-delete]`. The row stays and the name gains `(Deleted)`. The spec asserts the word `Deleted`.
- Routing and account numbers in the create journey are 9 digits. Shorter values are the error journey, not a successful create.
- The empty-list case rewrites a GraphQL response. Without that rewrite the seeded user has an account and the empty header will not show. Report that as unmet if you cannot apply the same intercept. Do not delete the user's account and call it the empty-state proof unless the assertions above still pass.
- Submit on this form is `[data-test=bankaccount-submit]`. The create spec clicks `[data-test*=submit]`.
