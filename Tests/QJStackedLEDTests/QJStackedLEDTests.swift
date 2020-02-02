import XCTest
@testable import QJStackedLED

final class QJStackedLEDTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(QJStackedLED().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
