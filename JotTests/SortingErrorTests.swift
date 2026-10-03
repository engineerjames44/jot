import Testing
@testable import Jot

/// The server's error codes (ADR-002) must map to messages a user can act on.
struct SortingErrorTests {
    @Test func dailyLimitIsDistinct() {
        #expect(SortingError(status: 429, code: "daily_limit") == .dailyLimit)
        #expect(SortingError(status: 429, code: "rate_limited") == .busy)
    }

    @Test func unreadableAndBadRequest() {
        #expect(SortingError(status: 422, code: "refused") == .unreadable)
        #expect(SortingError(status: 400, code: "bad_request") == .unreadable)
    }

    @Test func serverFailuresAreRetryable() {
        let error = SortingError(status: 502, code: "upstream")
        #expect(error == .unavailable)
        #expect(error.isRetryable)
        #expect(!SortingError.dailyLimit.isRetryable)
    }

    @Test func messagesNeverExposeServerDetails() {
        for error in [SortingError.offline, .busy, .dailyLimit, .unavailable, .unreadable] {
            let message = error.errorDescription ?? ""
            #expect(!message.isEmpty)
            #expect(!message.contains("{"))
        }
    }
}
