# New transaction

New transaction lets a signed-in user pay a contact or request money, see why an amount or note was rejected, and confirm the other person's balance changed.

## Sub-features

- `txn-pay` pays a contact and shows `Transaction Submitted!`.
- `txn-request` requests money from a contact and shows the same success alert.
- `txn-form-errors` requires an amount and a note and keeps both submit buttons disabled.
- `txn-pay-receiver` shows the payment on the receiver's balance.
- `txn-request-accept` lets the receiver accept the request.

## How to get to it (user POV)

- Sign in, then choose New in the top bar (`[data-test=nav-top-new-transaction]`).
- Open `http://localhost:3000/transaction/new` while signed in.
- Pick a person from the search results, enter an amount and a note, then choose Pay or Request.

## Driving it with Cypress

Preconditions:

- Doctor reports this run's instance.
- `cy.task("db:seed")` has run, as in `cypress/tests/ui/new-transaction.spec.ts`.
- The spec loads every user with `cy.database("filter", "users")`. `users[0]` is the sender. `users[1]` is the contact. It signs the sender in with `cy.loginByXstate`.

Run the maintained assertions with:

```shell
yarn cypress:run --spec cypress/tests/ui/new-transaction.spec.ts
```

- **Pay.** Click `[data-test*=new-transaction]` (the top-bar control is `[data-test=nav-top-new-transaction]`). Type the contact's first name into `[data-test=user-list-search-input]`. Click the `[data-test*=user-list-item]` that contains that first name. Type `[data-test*=amount-input]` `35` and `[data-test*=description-input]` `Sushi dinner 🍣`. Click `[data-test*=submit-payment]`. `[data-test=alert-bar-success]` is visible and its text is `Transaction Submitted!`. The sidenav `[data-test*=user-balance]` contains the sender's balance minus $35.00.
- **Request.** The same path, with amount `95` and description `Fancy Hotel 🏨`, then `[data-test*=submit-request]` (`[data-test=transaction-create-submit-request]`). The success alert text is `Transaction Submitted!`. `[data-test*=return-to-transactions]` then `[data-test*=personal-tab]` (`[data-test=nav-personal-tab]`) shows a `[data-test*=transaction-item]` containing that description.
- **Form errors.** Open new transaction, click the contact's `[data-test*=user-list-item]`. Type `43` into `[data-test*=amount-input]`, clear it, and blur. `#transaction-create-amount-input-helper-text` contains `Please enter a valid amount`. Type `Fun` into `[data-test*=description-input]`, clear it, and blur. `#transaction-create-description-input-helper-text` contains `Please enter a note`. `[data-test*=submit-request]` and `[data-test*=submit-payment]` are disabled.
- **Receiver balance and accept.** Keep the spec's later tests intact. They switch users with `cy.switchUserByXstate` and check the receiver's balance or the accept control `[data-test*=transaction-accept-request]`. Do not drop those assertions to make a sender-only run count.

## Gotchas

- Amount and description inputs are `[data-test=transaction-create-amount-input]` and `[data-test=transaction-create-description-input]`. The spec uses the `*=` form.
- Search results are `[data-test=user-list-item-<id>]`. Match the contact's first name. The search input's `data-test` is on the inner input.
- The success alert is `[data-test=alert-bar-success]`, rendered from `alert-bar-` plus the severity. The text is `Transaction Submitted!` for both pay and request.
- Balance text is formatted US currency. Compare what the sidenav shows, not a raw cent integer.
- `[data-test*=new-transaction]` also matches later controls such as `[data-test=new-transaction-create-another-transaction]`. Click it from the home screen, where the top-bar button is the match.
