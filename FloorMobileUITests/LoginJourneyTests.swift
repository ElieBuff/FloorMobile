//
//  LoginJourneyTests.swift
//  FloorMobileUITests
//

import XCTest

/// The one end-to-end UI test: a real login against the dev Zitadel instance.
///
/// Skipped when `TestCredentialsSecret.json` is absent (e.g. a CI without
/// secrets). It drives the real login web page, so it is inherently
/// sensitive to Zitadel's markup — kept deliberately tolerant (first-match
/// fields, form submission via the return key rather than button labels).
final class LoginJourneyTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSignInFromScratchReachesTheMainScreen() throws {
        guard let credentials = TestCredentials.load() else {
            throw XCTSkip("No TestCredentialsSecret.json — copy TestCredentials.example.json and fill it in")
        }

        let app = XCUIApplication()
        app.launchArguments = ["--wipe-session"]
        app.launch()

        // Wiped session: the login screen must show.
        let signIn = app.buttons["Sign in"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 10), "Login screen should appear after a wiped session")
        signIn.tap()

        // Zitadel page, step 1: user name.
        let webView = app.webViews.firstMatch
        let loginField = webView.textFields.firstMatch
        XCTAssertTrue(loginField.waitForExistence(timeout: 30), "Zitadel login page should load in the sheet")
        loginField.tap()
        loginField.typeText(credentials.username)
        Self.submitForm(app)

        // Step 2: password.
        let passwordField = webView.secureTextFields.firstMatch
        XCTAssertTrue(passwordField.waitForExistence(timeout: 30), "Password step should follow the user name")
        passwordField.tap()
        passwordField.typeText(credentials.password)
        Self.submitForm(app)

        // Safari offers to save the password; decline so the flow can finish.
        let notNow = app.buttons["Not Now"].firstMatch
        if notNow.waitForExistence(timeout: 5) {
            notNow.tap()
        }

        // Callback, token exchange, sync — then the Home screen.
        let mainScreen = app.staticTexts["AI recommendations"]
        XCTAssertTrue(mainScreen.waitForExistence(timeout: 60), "App should reach the Home screen after login")
    }

    /// Submits the current Zitadel form.
    ///
    /// The keyboard's accessory bar covers the page's submit button (and its
    /// own disabled "Next" button shadows loose label queries), so the
    /// keyboard is dismissed first, then the page button is tapped by its
    /// exact label.
    @MainActor
    private static func submitForm(_ app: XCUIApplication) {
        let webView = app.webViews.firstMatch
        // Dismiss the keyboard first by tapping a neutral spot near the top
        // of the page — the keyboard covers the form's submit button.
        webView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()

        for label in ["Continue", "Login", "Sign in", "Next"] {
            let button = webView.buttons[label].firstMatch
            if button.waitForExistence(timeout: 2), button.isEnabled, button.isHittable {
                button.tap()
                return
            }
        }
        XCTFail("No enabled, hittable submit button found on the login page")
    }
}
