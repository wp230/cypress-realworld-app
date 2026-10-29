# Notifications

Notifications lets a signed-in user open the notification list, see a new like, comment, payment, or request, and see an empty list when there are none.

## Sub-features

- `notif-like` tells the other party that someone liked a transaction.
- `notif-comment` tells the other party that someone commented.
- `notif-payment` tells the receiver that someone paid them.
- `notif-request` tells the receiver that someone requested payment.
- `notif-empty` shows the empty header when the list request returns nothing.

## How to get to it (user POV)

- Sign in, then choose Notifications in the sidenav (`[data-test=sidenav-notifications]`). On a narrow viewport, open the drawer with `[data-test=sidenav-toggle]` first.
- Choose the bell (`[data-test=nav-top-notifications-link]`). The count is `[data-test=nav-top-notifications-count]`.
- Open `http://localhost:3000/notifications` while signed in.

## Driving it with Cypress

Preconditions:

- Doctor reports this run's instance.
- `cy.task("db:seed")` has run, as in `cypress/tests/ui/notifications.spec.ts`.
- `cy.database("filter", "users")` orders the actors: `users[0]`, `users[1]`, `users[2]` are User A, User B, and User C in that spec.
- Sign-in inside this spec is `cy.loginByXstate`. Switching users is `cy.switchUserByXstate`.

Run the maintained assertions with:

```shell
yarn cypress:run --spec cypress/tests/ui/notifications.spec.ts
```

- **Like.** Sign in as User A. Open a transaction whose sender is User B (`cy.visit("/transaction/<id>")` with the id from `cy.database("find", "transactions", { senderId })`). `[data-test=nav-top-notifications-count]` equals the current notification count. Click `[data-test*=like-button]`. The button becomes disabled and `[data-test*=transaction-like-count]` contains `1`. Switch to User B, click `[data-test*=notifications-link]`, and the first `[data-test*=notification-list-item]` contains User A's first name and `liked`. The spec also asserts a list length. Keep that assertion.
- **Comment.** As User A, open a transaction sent by User B. Type `Thank You` into `[data-test*=comment-input]` and press Enter. Switch to User B and open notifications. The first `[data-test*=notification-list-item]` contains User A's first name and `commented`.
- **Payment and request.** The spec's payment and request cases create a transaction, switch users, open `[data-test*=notifications-link]`, and expect the list item to name the sender. The request case contains `requested payment`. Keep those tests whole.
- **Empty.** Intercept `GET /notifications` with an empty array, sign in as User A, click `[data-test=sidenav-notifications]`. The path equals `/notifications`. `[data-test=notification-list]` does not exist. `[data-test=empty-list-header]` contains `No Notifications`.

## Gotchas

- The list that renders is `[data-test=notifications-list]` and each row is `[data-test=notification-list-item-<id>]`. The empty-state spec asserts that `[data-test=notification-list]` (no `s`) does not exist. Do not "correct" that assertion in the spec. When you need the visible list, use `notifications-list`.
- Like and comment controls are `[data-test=transaction-like-button-<id>]` and `[data-test=transaction-comment-input-<id>]`. The spec's `*=` selectors match them.
- Notification counts in the spec depend on the dev seed. If the length assertion fails, report it. Do not lower the expected length.
- The empty state is an intercept of `GET /notifications`, not a freshly created user. A seeded user has notifications. Do not claim the empty header without that intercept.
- `[data-test*=notifications-link]` matches `[data-test=nav-top-notifications-link]`.
