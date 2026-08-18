import Foundation
import XCTest
@testable import Entrevoix

final class CodexOAuthTests: XCTestCase {
    func testAuthorizationURLUsesPKCELoopbackAndCSRFState() throws {
        let client = CodexOAuthTokenClient()
        let redirectURI = URL(string: "http://localhost:1455/auth/callback")!
        let url = client.authorizationURL(redirectURI: redirectURI, challenge: "challenge-value", state: "state-value")
        let items = Dictionary(uniqueKeysWithValues: try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems).map { ($0.name, $0.value) })

        XCTAssertEqual(url.host, "auth.openai.com")
        XCTAssertEqual(items["redirect_uri"], redirectURI.absoluteString)
        XCTAssertEqual(items["code_challenge"], "challenge-value")
        XCTAssertEqual(items["code_challenge_method"], "S256")
        XCTAssertEqual(items["state"], "state-value")
        XCTAssertEqual(items["scope"], "openid profile email offline_access")
    }
}
