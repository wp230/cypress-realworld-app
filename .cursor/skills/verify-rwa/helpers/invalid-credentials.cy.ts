/// <reference path="../../../../cypress/global.d.ts" />

// Replay of the invalid-credential cases in cypress/tests/ui/auth.spec.ts.
// The have.text assertions are the same strings as that spec. Do not weaken them.
// cy.screenshot is added so a passing run still leaves a local PNG. cy.visualSnapshot
// in the original spec uploads to Percy and does not write a file in this repo.

describe("verify-rwa invalid credentials", () => {
  beforeEach(() => {
    cy.task("db:seed");
  });

  it("should error for an invalid user", () => {
    cy.login("invalidUserName", "invalidPa$$word");

    cy.getBySel("signin-error")
      .should("be.visible")
      .and("have.text", "Username or password is invalid");
    cy.location("pathname").should("equal", "/signin");
    cy.getCookie("connect.sid").should("not.exist");
    cy.screenshot("auth-invalid-user");
  });

  it("should error for an invalid password for existing user", () => {
    cy.database("find", "users").then((user: { username: string }) => {
      cy.login(user.username, "INVALID");
    });

    cy.getBySel("signin-error")
      .should("be.visible")
      .and("have.text", "Username or password is invalid");
    cy.location("pathname").should("equal", "/signin");
    cy.getCookie("connect.sid").should("not.exist");
    cy.screenshot("auth-invalid-password");
  });
});
