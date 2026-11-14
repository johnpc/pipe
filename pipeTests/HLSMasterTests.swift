import Testing
import Foundation
@testable import pipe

/// Parsing YouTube's HLS master and choosing the audio rendition to play.
struct HLSMasterTests {
    static let base = URL(string: "https://manifest.googlevideo.com/api/manifest/hls_variant/x/master.m3u8")!
    /// Shape of a real YouTube master: two audio groups (233 = HE-AAC, 234 = AAC),
    /// one rendition per language per group, variants referencing a group.
    static let text = """
    #EXTM3U
    #EXT-X-INDEPENDENT-SEGMENTS
    #EXT-X-MEDIA:URI="https://m/233/en.m3u8",TYPE=AUDIO,GROUP-ID="233",LANGUAGE="en-US",NAME="American English - original",YT-EXT-XTAGS="abc",DEFAULT=NO,AUTOSELECT=YES
    #EXT-X-MEDIA:URI="https://m/233/es.m3u8",TYPE=AUDIO,GROUP-ID="233",LANGUAGE="es-US",NAME="Spanish (US)",DEFAULT=NO,AUTOSELECT=YES
    #EXT-X-MEDIA:URI="https://m/234/en.m3u8",TYPE=AUDIO,GROUP-ID="234",LANGUAGE="en-US",NAME="American English - original",DEFAULT=NO,AUTOSELECT=YES
    #EXT-X-MEDIA:URI="234/es.m3u8",TYPE=AUDIO,GROUP-ID="234",LANGUAGE="es-US",NAME="Spanish, US",DEFAULT=YES,AUTOSELECT=YES
    #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",LANGUAGE="en",NAME="English",URI="https://m/subs.m3u8"
    #EXT-X-STREAM-INF:BANDWIDTH=310049,CODECS="avc1.4D4015,mp4a.40.5",RESOLUTION=426x240,AUDIO="233",CLOSED-CAPTIONS=NONE
    https://m/v/240.m3u8
    #EXT-X-STREAM-INF:BANDWIDTH=4500000,CODECS="avc1.640028,mp4a.40.2",RESOLUTION=1920x1080,AUDIO="234",CLOSED-CAPTIONS=NONE
    https://m/v/1080.m3u8
    """

    let master = HLSMaster.parse(text, relativeTo: base)

    @Test func parsesAudioRenditionsAndVariants() {
        #expect(master.renditions.count == 4)  // subtitles are not audio
        #expect(master.variants.map(\.bandwidth) == [310049, 4500000])
        #expect(master.variants.map(\.audioGroup) == ["233", "234"])
        let es234 = master.renditions[3]
        #expect(es234.language == "es-US")
        #expect(es234.name == "Spanish, US")  // quoted comma survives
        #expect(es234.isDefault)
        #expect(es234.uri.absoluteString == "https://manifest.googlevideo.com/api/manifest/hls_variant/x/234/es.m3u8")  // relative URI
        #expect(master.renditions[0].isOriginal && !es234.isOriginal)
    }

    @Test func attributeParsingHandlesQuotesAndEmptyValues() {
        let attrs = HLSMaster.attributes("A=1,B=\"x,y\",C=,D=\"\"")
        #expect(attrs == ["A": "1", "B": "x,y", "C": "", "D": ""])
    }

    @Test func bestAudioGroupFollowsTheHighestBandwidthVariant() {
        #expect(master.bestAudioGroup == "234")
        #expect(HLSMaster(renditions: [], variants: []).bestAudioGroup == nil)
    }

    @Test func choosesPreferredLanguageInTheBestGroup() {
        #expect(master.audioRendition(preferred: "es")?.uri.lastPathComponent == "es.m3u8")
        #expect(master.audioRendition(preferred: "es")?.groupId == "234")
        #expect(master.audioRendition(preferred: "es-US")?.groupId == "234")
    }

    @Test func fallsBackToEnglishThenOriginalThenDefault() {
        #expect(master.audioRendition(preferred: "fr")?.language == "en-US")
        #expect(master.audioRendition(preferred: AudioLanguageLogic.original)?.isOriginal == true)
        let noEnglish = HLSMaster(renditions: [
            .init(groupId: "g", language: "de", name: "German", isDefault: false, uri: URL(string: "https://m/de")!),
            .init(groupId: "g", language: "fr", name: "French", isDefault: true, uri: URL(string: "https://m/fr")!),
        ], variants: [.init(bandwidth: 1, audioGroup: "g")])
        #expect(noEnglish.audioRendition(preferred: "it")?.language == "fr")  // DEFAULT=YES
        #expect(HLSMaster(renditions: [], variants: []).audioRendition(preferred: "en") == nil)
    }

    @Test func unknownGroupOnVariantsStillYieldsARendition() {
        let odd = HLSMaster(renditions: master.renditions, variants: [.init(bandwidth: 9, audioGroup: "zzz")])
        #expect(odd.audioRendition(preferred: "en") != nil)
    }
}
