import Testing
@testable import pipe

struct ChannelFormatTests {
    @Test func formatsBillions() {
        #expect(ChannelFormat.subscribers(2_300_000_000) == "2.3B subscribers")
    }

    @Test func formatsMillionsDroppingTrailingZero() {
        #expect(ChannelFormat.subscribers(505_000_000) == "505M subscribers")
        #expect(ChannelFormat.subscribers(1_500_000) == "1.5M subscribers")
    }

    @Test func formatsThousands() {
        #expect(ChannelFormat.subscribers(12_300) == "12.3K subscribers")
    }

    @Test func formatsSmallCountsExactly() {
        #expect(ChannelFormat.subscribers(950) == "950 subscribers")
    }

    @Test func nilForNilOrNonPositive() {
        #expect(ChannelFormat.subscribers(nil) == nil)
        #expect(ChannelFormat.subscribers(0) == nil)
        #expect(ChannelFormat.subscribers(-5) == nil)
    }

    @Test func searchItemExposesVerifiedAndSubscriberText() {
        let item = SearchItem(url: "/channel/c", type: "channel", title: nil, thumbnail: nil, uploaderName: nil, uploaderUrl: nil, duration: nil, name: "Chan", uploadedDate: nil, verified: true, subscribers: 1_000_000)
        #expect(item.isVerified == true)
        #expect(item.subscriberText == "1M subscribers")
    }

    @Test func searchItemDefaultsWhenFieldsMissing() {
        let item = SearchItem(url: "/channel/c", type: "channel", title: nil, thumbnail: nil, uploaderName: nil, uploaderUrl: nil, duration: nil, name: "Chan", uploadedDate: nil, verified: nil, subscribers: nil)
        #expect(item.isVerified == false)
        #expect(item.subscriberText == nil)
    }
}
