import Foundation
import Testing
@testable import Jot

struct JotLinkTests {
    @Test func roundTrips() {
        let id = UUID()
        #expect(JotLink(url: JotLink.item(id).url) == .item(id))
        #expect(JotLink(url: JotLink.record.url) == .record)
    }

    @Test(arguments: ["https://jot/record", "jot://item/not-a-uuid", "jot://unknown", "jot://item"])
    func rejectsOtherURLs(_ string: String) {
        #expect(JotLink(url: URL(string: string)!) == nil)
    }
}
