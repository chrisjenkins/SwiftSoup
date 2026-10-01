import XCTest
@testable import SwiftSoup

/// Public-API regression tests for #392: a vertical tab (`0x0B`) after a quoted attribute value
/// produces an attribute key that trims to empty during materialization. Parsing then `select`ing
/// must drop the malformed attribute rather than trap.
final class PublicEmptyAttributeKeyTest: XCTestCase {

    /// Readability's JSON-LD lookup indexes attributes on unrelated elements too.
    func testJSONLDSelectorDropsMalformedKeysAndPreservesMetadata() throws {
        let json = #"{"@type":"NewsArticle","headline":"Example headline"}"#
        for malformedAttribute in ["\u{0B}", "\u{0B}=x", "\u{0B}=\"\"", "\u{0B}=\"a&amp;b\""] {
            let html = """
                <div a="b"\(malformedAttribute)>Article body</div>
                <script type="application/ld+json" a="b"\(malformedAttribute)>\(json)</script>
                """
            let doc = try SwiftSoup.parse(html)
            let matches = try doc.select("script[type=application/ld+json]")

            XCTAssertEqual(matches.size(), 1, malformedAttribute)
            let script = try XCTUnwrap(matches.first())
            XCTAssertEqual(script.data(), json)
            XCTAssertEqual(try script.attr("type"), "application/ld+json")
            XCTAssertEqual(try script.attr("a"), "b")
            XCTAssertEqual(script.getAttributes()?.size(), 2)
            let div = try XCTUnwrap(doc.select("div").first())
            XCTAssertEqual(div.getAttributes()?.size(), 1)
        }
    }

    /// Boolean attribute (`.none` value).
    func testBooleanVerticalTabKeyDoesNotCrashSelect() throws {
        let doc = try SwiftSoup.parse("<div a=\"b\"\u{0B}>hi</div>")
        let matches = try doc.select("[name=x]")
        XCTAssertEqual(matches.size(), 0, "Malformed empty-key attribute must be dropped, not crash")
    }

    /// Valued attribute (`.slice` value).
    func testValuedVerticalTabKeyDoesNotCrashSelect() throws {
        let doc = try SwiftSoup.parse("<div a=\"b\"\u{0B}=x>hi</div>")
        let matches = try doc.select("[name=x]")
        XCTAssertEqual(matches.size(), 0)
    }

    /// `<meta>` + the attribute-value selector from the original report.
    func testMetaVerticalTabKeyDoesNotCrashSelect() throws {
        let doc = try SwiftSoup.parse("<meta a=\"b\"\u{0B}=og:title>")
        let matches = try doc.select("meta[property=og:title]")
        XCTAssertEqual(matches.size(), 0)
    }
}
