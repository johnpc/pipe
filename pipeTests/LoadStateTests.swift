import Testing
@testable import pipe

struct LoadStateTests {
    @Test func loadingFlags() {
        let s = LoadState<Int>.loading
        #expect(s.isLoading == true)
        #expect(s.didFail == false)
        #expect(s.value == nil)
    }

    @Test func loadedFlags() {
        let s = LoadState.loaded(42)
        #expect(s.isLoading == false)
        #expect(s.didFail == false)
        #expect(s.value == 42)
    }

    @Test func failedFlags() {
        let s = LoadState<Int>.failed
        #expect(s.isLoading == false)
        #expect(s.didFail == true)
        #expect(s.value == nil)
    }

    @Test func fromNilIsFailed() {
        let s = LoadState<Int>.from(nil)
        #expect(s == .failed)
    }

    @Test func fromValueIsLoaded() {
        let s = LoadState.from(7)
        #expect(s == .loaded(7))
    }
}
