import { User } from "../../../src/models";
import { isMobile } from "../../support/utils";

type LoginInterception = {
  request: { body: { username?: string; password?: string } };
  response?: { statusCode?: number };
};

describe("Sign-in retry", function () {
  beforeEach(function () {
    cy.task("db:seed");

    cy.database("find", "users").then((user: User) => {
      this.user = user;
    });
  });

  it("accepts a corrected password on the same sign-in page without reloading", function () {
    const user = this.user as User;

    cy.visit("/signin");

    cy.window().then((win) => {
      (win as Cypress.CustomWindow & { __authRetryMarker?: string }).__authRetryMarker =
        "no-reload";
    });

    cy.login(user.username, "INVALID");

    cy.get<LoginInterception>("@loginUser").should((loginUser) => {
      expect(loginUser.response?.statusCode).to.eq(401);
      expect(loginUser.request.body.username).to.eq(user.username);
      expect(loginUser.request.body.password).to.eq("INVALID");
    });

    cy.getBySel("signin-error")
      .should("be.visible")
      .and("have.text", "Username or password is invalid");
    cy.location("pathname").should("eq", "/signin");
    cy.getCookie("connect.sid").should("not.exist");
    cy.window().its("authService.state.value").should("eq", "unauthorized");
    cy.getBySel("sidenav-username").should("not.exist");
    cy.screenshot("invalid-password-still-signed-out");

    cy.getBySel("signin-username").find("input").clear();
    cy.getBySel("signin-password").find("input").clear();
    cy.getBySel("signin-username").find("input").should("have.value", "");
    cy.getBySel("signin-password").find("input").should("have.value", "");

    cy.login(user.username, "s3cret");

    cy.get<LoginInterception>("@loginUser").should((loginUser) => {
      expect(loginUser.response?.statusCode).to.eq(200);
      expect(loginUser.request.body.username).to.eq(user.username);
      expect(loginUser.request.body.password).to.eq("s3cret");
    });

    cy.location("pathname").should("equal", "/");
    if (isMobile()) {
      cy.getBySel("sidenav-toggle").click();
    }
    cy.getBySel("sidenav-username").should("be.visible").and("have.text", `@${user.username}`);
    cy.getBySel("transaction-list").should("be.visible");
    cy.getBySel("signin-error").should("not.exist");

    cy.window().should((win) => {
      expect(
        (win as Cypress.CustomWindow & { __authRetryMarker?: string }).__authRetryMarker
      ).to.eq("no-reload");
    });
    cy.screenshot("signed-in-after-retry");
  });
});
